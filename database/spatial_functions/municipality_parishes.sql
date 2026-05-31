CREATE OR REPLACE FUNCTION municipality_parishes(
    municipality_name text,
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
    WITH parishes_geom AS (
        SELECT
            territory_code,
            territory_name,
            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(geom, 3),
                precision_value
            ) AS geom
        FROM wh.dim_territory
        WHERE territory_level = 'parish'
          AND parent_name = municipality_name
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
    FROM parishes_geom;

    RETURN svg;
END;
$$
LANGUAGE plpgsql
IMMUTABLE;
