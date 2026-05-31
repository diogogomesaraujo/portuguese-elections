CREATE OR REPLACE FUNCTION country(
    stroke text,
    strokewidth text,
    fill text,
    fillopacity text,
    precision_value integer
)
RETURNS text AS
$$
DECLARE
    svg text;
BEGIN
    WITH municipality_geom AS (
        SELECT
            parent_name AS distrito_ilha,
            territory_name AS municipio,
            ST_Scale(
                ST_Transform(
                    ST_Union(ST_CollectionExtract(geom, 3)),
                    4326
                ),
                10000,
                10000
            ) AS geom
        FROM wh.dim_territory
        WHERE territory_level = 'municipality'
          AND geom IS NOT NULL
        GROUP BY parent_name, territory_name
    ),
    district_geom AS (
        SELECT
            distrito_ilha,
            ST_Union(geom) AS geom
        FROM municipality_geom
        GROUP BY distrito_ilha
    ),
    country_geom AS (
        SELECT
            distrito_ilha,
            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(geom, 3),
                precision_value
            ) AS geom
        FROM district_geom
        WHERE geom IS NOT NULL
          AND NOT ST_IsEmpty(geom)
    )
    SELECT svgdoc(
        content => array_agg(
            svgshape(
                ST_CollectionExtract(geom, 3),
                title => distrito_ilha,
                style => svgstyleprop(
                    stroke => stroke::text,
                    strokewidth => strokewidth::text,
                    fill => fill::text,
                    fillopacity => fillopacity::text
                )
            )
            ORDER BY distrito_ilha
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM country_geom;

    RETURN svg;
END;
$$
LANGUAGE plpgsql
STABLE;
