CREATE OR REPLACE FUNCTION district_municipalities(
    district_name text,
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
    WITH municipalities_geom AS (
        SELECT
            territory_code,
            territory_name,
            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(
                    ST_Scale(
                        ST_Transform(geom, 4326),
                        10000,
                        10000
                    ),
                    3
                ),
                precision_value
            ) AS geom
        FROM wh.dim_territory
        WHERE territory_level = 'municipality'
          AND parent_name = district_name
          AND geom IS NOT NULL
    )
    SELECT svgdoc(
        content => array_agg(
            svgshape(
                ST_CollectionExtract(geom, 3),
                title => territory_name,
                style => svgstyleprop(
                    stroke => stroke::text,
                    strokewidth => strokewidth::text,
                    fill => fill::text,
                    fillopacity => fillopacity::text
                )
            )
            ORDER BY territory_code
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM municipalities_geom
    WHERE geom IS NOT NULL
      AND NOT ST_IsEmpty(geom);

    RETURN svg;
END;
$$
LANGUAGE plpgsql
STABLE;
