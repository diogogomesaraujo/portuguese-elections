open Pg
open Caqti_request.Infix

module Map = struct
  let country_districts ~precision =
    let query =
      Printf.sprintf
        "WITH district_geoms AS (
            SELECT
                distrito_ilha,
                st_union(st_simplifypreservetopology(geom, %d)) as geom
            FROM cont_freguesias
            GROUP BY distrito_ilha
        )
        SELECT distrito_ilha, st_assvg(st_translate(st_convexhull(geom), -st_xmin(geom), -st_ymin(geom))) FROM district_geoms;"
        precision in
    Caqti_type.(unit ->* t2 string string) query


  let district_municipalities ~district ~precision =
    let query =
      Printf.sprintf
        "WITH municipio_geoms AS (
            SELECT
              municipio,
              st_union(st_simplifypreservetopology(geom, %d)) as geom
            FROM cont_freguesias
            WHERE distrito_ilha = '%s'
            GROUP BY municipio
        )
        SELECT municipio, st_assvg(st_translate(st_convexhull(geom), -st_xmin(geom), -st_ymin(geom))) FROM municipio_geoms;"
        precision district
    in
    Caqti_type.(unit ->* t2 string string) query

  let municipality_parishes ~municipality ~precision =
    let query =
      Printf.sprintf
        "WITH municipio_geoms AS (
            SELECT
                municipio,
                st_union(st_simplifypreservetopology(geom, %d)) as geom
            FROM cont_freguesias
            WHERE distrito_ilha = '%s'
            GROUP BY municipio
        )
        SELECT municipio, st_assvg(st_translate(st_convexhull(geom), -st_xmin(geom), -st_ymin(geom))) as svg FROM municipio_geoms;"
        precision municipality
    in
    Caqti_type.(unit ->* t2 string string) query

  let parish ~parish ~precision =
    let query =
      Printf.sprintf
        "WITH parish AS(SELECT st_scale(st_transform(st_normalize(st_simplifypreservetopology(geom, %d)), 4326), 1000, -1000) as geom
                       FROM cont_freguesias
                       WHERE freguesia = '%s'
                       GROUP BY geom)
        SELECT svgdoc(
                       content=> array_agg(svgshape(geom, title => '%s', style => svgStyle(
                               'stroke', '#000000',
                               'stroke-width', 0.1::text,
                               'fill', 'green',
                               'stroke-linejoin', 'round' ))),
                       viewbox => svgviewbox(st_collect(geom))
               )
        FROM parish;"
        precision parish parish
    in
    Caqti_type.(unit ->! string) query
end
