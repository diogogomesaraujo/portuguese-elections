CREATE OR REPLACE FUNCTION municipality_parishes(  municipality text,
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
svg := (WITH municipalities_geom AS (
    SELECT
        freguesia,
        st_scale(st_transform(st_union(geom), 4326), 10000, 10000)
        AS geom
    FROM cont_freguesias
    WHERE municipio = municipality
    GROUP BY freguesia
)
SELECT svgdoc(
               content=> array_agg(svgshape(geom,
                                            title => freguesia,
                                            style => svgstyleprop(
                                                    stroke => stroke,
                                                    strokewidth => strokewidth,
                                                    fill => fill,
                                                    fillopacity =>  fillopacity))),
               viewbox => svgviewbox(st_collect(geom))
       )
FROM municipalities_geom);
RETURN svg;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;