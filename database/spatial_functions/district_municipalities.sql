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
                ST_CollectionExtract(geom, 3),
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
                geom,
                title => territory_name,
                style => svgstyleprop(
                    stroke => stroke,
                    strokewidth => strokewidth,
                    fill => fill,
                    fillopacity => fillopacity
                )
            )
            ORDER BY territory_code
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM municipalities_geom;

    RETURN svg;
END;
$$
LANGUAGE plpgsql
IMMUTABLE;
