CREATE OR REPLACE FUNCTION country (stroke   text,
                                    strokewidth text,
                                    fill text,
                                    fillopacity text,
                                    precision_value integer)
RETURNS text AS
$$
DECLARE
svg text;
BEGIN
svg := (WITH municipality_geom AS (
SELECT
    distrito_ilha,
    municipio,
    st_scale(st_transform(st_union(geom), 4326), 500000, 500000)
    AS geom
FROM cont_freguesias
GROUP BY municipio, distrito_ilha
),
district_geom AS (
SELECT
    distrito_ilha,
    st_union(geom) AS geom
FROM municipality_geom
GROUP BY distrito_ilha
),
country_geom AS (
SELECT
    distrito_ilha,
    st_simplifypreservetopology(st_collectionextract(geom), precision_value) AS geom
FROM district_geom)
SELECT svgdoc(
               content=> array_agg(svgshape(st_collectionextract(geom),
                                            title => distrito_ilha,
                                            style => svgstyleprop(
                                                    stroke => stroke,
                                                    strokewidth => strokewidth,
                                                    fill => fill,
                                                    fillopacity =>  fillopacity))),
               viewbox => svgviewbox(st_collect(geom))
       )
FROM country_geom);
RETURN svg;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;