CREATE OR REPLACE FUNCTION district_municipalities(district text,
                                                   stroke   text,
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
        municipio,
        st_scale(st_transform(st_union(geom), 4326), 10000, 10000)
        AS geom
    FROM cont_freguesias
    WHERE distrito_ilha = district
    GROUP BY municipio
),
municipalities_geoms AS (
SELECT municipio,
           st_simplifypreservetopology((st_collectionextract(geom), precision_value)
           AS geom
FROM municipality_geom)
SELECT svgdoc(
               content=> array_agg(svgshape(geom,
                                            title => municipio,
                                            style => svgstyleprop(
                                                    stroke => stroke,
                                                    strokewidth => strokewidth,
                                                    fill => fill,
                                                    fillopacity =>  fillopacity))),
               viewbox => svgviewbox(st_collect(geom))
       )
FROM municipalities_geoms);
RETURN svg;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;