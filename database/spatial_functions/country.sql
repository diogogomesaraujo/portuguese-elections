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
    SELECT svgdoc(
        content => array_agg(
            svgshape(
                ST_CollectionExtract(geom, 3),
                title => territory_name,
                style => svgstyleprop(
                    stroke => stroke,
                    strokewidth => strokewidth,
                    fill => fill,
                    fillopacity => fillopacity
                )
            )
        ),
        viewbox => svgviewbox(ST_Collect(geom))
    )
    INTO svg
    FROM (
        SELECT
            territory_name,
            ST_SimplifyPreserveTopology(
                ST_CollectionExtract(geom, 3),
                precision_value
            ) AS geom
        FROM wh.dim_territory
        WHERE territory_level = 'country'
          AND geom IS NOT NULL
    ) country_geom;

    RETURN svg;
END;
$$
LANGUAGE plpgsql
IMMUTABLE;
