DROP PROCEDURE IF EXISTS op.load_territories_from_spatial_data();

CREATE PROCEDURE op.load_territories_from_spatial_data()
LANGUAGE plpgsql
AS $$
BEGIN
    CREATE TEMP TABLE tmp_spatial_parish (
        dtmnfr text,
        freguesia text,
        municipio text,
        distrito_ilha text,
        geom geometry(MultiPolygon, 4326),
        source_table text,
        source_srid int
    ) ON COMMIT DROP;

    IF to_regclass('public.cont_freguesias') IS NOT NULL THEN
        INSERT INTO tmp_spatial_parish
        SELECT
            lpad(c.dtmnfr::text, 6, '0'),
            c.freguesia,
            c.municipio,
            c.distrito_ilha,
            ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Transform(c.geom, 4326)), 3))::geometry(MultiPolygon, 4326), 'cont_freguesias', ST_SRID(c.geom)
        FROM public.cont_freguesias c
        WHERE c.dtmnfr IS NOT NULL
          AND c.geom IS NOT NULL;
    END IF;

    IF to_regclass('public.raa_cen_ori_freguesias') IS NOT NULL THEN
        INSERT INTO tmp_spatial_parish
        SELECT
            lpad(c.dtmnfr::text, 6, '0'),
            c.freguesia,
            c.municipio,
            c.distrito_ilha,
            ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Transform(c.geom, 4326)), 3))::geometry(MultiPolygon, 4326),
            'raa_cen_ori_freguesias',
            ST_SRID(c.geom)
        FROM public.raa_cen_ori_freguesias c
        WHERE c.dtmnfr IS NOT NULL
          AND c.geom IS NOT NULL;
    END IF;

    IF to_regclass('public.raa_oci_freguesias') IS NOT NULL THEN
        INSERT INTO tmp_spatial_parish
        SELECT
            lpad(c.dtmnfr::text, 6, '0'),
            c.freguesia,
            c.municipio,
            c.distrito_ilha,
            ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Transform(c.geom, 4326)), 3))::geometry(MultiPolygon, 4326),
            'raa_oci_freguesias',
            ST_SRID(c.geom)
        FROM public.raa_oci_freguesias c
        WHERE c.dtmnfr IS NOT NULL
          AND c.geom IS NOT NULL;
    END IF;

    IF to_regclass('public.ram_freguesias') IS NOT NULL THEN
        INSERT INTO tmp_spatial_parish
        SELECT
            lpad(c.dtmnfr::text, 6, '0'),
            c.freguesia,
            c.municipio,
            c.distrito_ilha,
            ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_Transform(c.geom, 4326)), 3))::geometry(MultiPolygon, 4326),
            'ram_freguesias',
            ST_SRID(c.geom)
        FROM public.ram_freguesias c
        WHERE c.dtmnfr IS NOT NULL
          AND c.geom IS NOT NULL;
    END IF;

    INSERT INTO op.territory (
        level_id,
        code,
        name,
        parent_id,
        geom,
        source_table,
        source_srid
    )
    SELECT
        tl.territory_level_id,
        'PT',
        'Portugal',
        NULL,
        ST_Multi(ST_UnaryUnion(ST_Collect(p.geom)))::geometry(MultiPolygon, 4326),
        'spatial boundaries aggregated',
        4326
    FROM tmp_spatial_parish p
    JOIN op.territory_level tl ON tl.code = 'country'
    GROUP BY tl.territory_level_id
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        parent_id = EXCLUDED.parent_id,
        geom = EXCLUDED.geom,
        source_table = EXCLUDED.source_table,
        source_srid = EXCLUDED.source_srid,
        updated_at = now();

    INSERT INTO op.territory (
        level_id,
        code,
        name,
        parent_id,
        geom,
        source_table,
        source_srid
    )
    SELECT
        tl.territory_level_id,
        left(p.dtmnfr, 2),
        COALESCE(max(p.distrito_ilha), 'Distrito ' || left(p.dtmnfr, 2)),
        max(country.territory_id),
        ST_Multi(ST_UnaryUnion(ST_Collect(p.geom)))::geometry(MultiPolygon, 4326),
        'spatial boundaries aggregated',
        4326
    FROM tmp_spatial_parish p
    JOIN op.territory_level tl ON tl.code = 'district'
    JOIN op.territory country ON country.code = 'PT'
    GROUP BY tl.territory_level_id, left(p.dtmnfr, 2)
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        parent_id = EXCLUDED.parent_id,
        geom = EXCLUDED.geom,
        source_table = EXCLUDED.source_table,
        source_srid = EXCLUDED.source_srid,
        updated_at = now();

    INSERT INTO op.territory (
        level_id,
        code,
        name,
        parent_id,
        geom,
        source_table,
        source_srid
    )
    SELECT
        tl.territory_level_id,
        left(p.dtmnfr, 4),
        COALESCE(max(p.municipio), left(p.dtmnfr, 4)),
        max(d.territory_id),
        ST_Multi(ST_UnaryUnion(ST_Collect(p.geom)))::geometry(MultiPolygon, 4326),
        'spatial boundaries aggregated',
        4326
    FROM tmp_spatial_parish p
    JOIN op.territory_level tl ON tl.code = 'municipality'
    JOIN op.territory d ON d.code = left(p.dtmnfr, 2)
    GROUP BY tl.territory_level_id, left(p.dtmnfr, 4)
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        parent_id = EXCLUDED.parent_id,
        geom = EXCLUDED.geom,
        source_table = EXCLUDED.source_table,
        source_srid = EXCLUDED.source_srid,
        updated_at = now();

    INSERT INTO op.territory (
        level_id,
        code,
        name,
        parent_id,
        geom,
        source_table,
        source_srid
    )
    SELECT
        tl.territory_level_id,
        p.dtmnfr,
        COALESCE(max(p.freguesia), p.dtmnfr),
        max(m.territory_id),
        ST_Multi(ST_UnaryUnion(ST_Collect(p.geom)))::geometry(MultiPolygon, 4326),
        max(p.source_table),
        max(p.source_srid)
    FROM tmp_spatial_parish p
    JOIN op.territory_level tl ON tl.code = 'parish'
    JOIN op.territory m ON m.code = left(p.dtmnfr, 4)
    GROUP BY tl.territory_level_id, p.dtmnfr
    ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        parent_id = EXCLUDED.parent_id,
        geom = EXCLUDED.geom,
        source_table = EXCLUDED.source_table,
        source_srid = EXCLUDED.source_srid,
        updated_at = now();
END;
$$;
