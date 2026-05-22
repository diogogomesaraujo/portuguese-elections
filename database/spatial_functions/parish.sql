CREATE OR REPLACE FUNCTION parish(parish text,
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
svg := (WITH parish_geom AS(SELECT st_scale(st_transform(st_normalize(st_simplifypreservetopology(geom, precision_value)), 4326), 10000, 10000) as geom
               FROM cont_freguesias
               WHERE freguesia = parish
               GROUP BY geom)
SELECT svgdoc(
               content=> array_agg(svgshape(geom,
                                            title => parish,
                                            style => svgstyleprop(
                                                    stroke => stroke,
                                                    strokewidth => strokewidth,
                                                    fill => fill,
                                                    fillopacity => fillopacity))),
               viewbox => svgviewbox(st_collect(geom))
       )
FROM parish_geom);
RETURN svg;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;