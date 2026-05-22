open Pg
open Caqti_request.Infix

(*
  Caqti infix operators

  ->! decodes a single row
  ->? decodes zero or one row
  ->* decodes many rows
  ->. expects no row
*)

module Map = struct
  let country_districts _ ~precision =
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
    Caqti_type.(unit ->? string) query


  let district_municipalities district ~precision =
    let query =
      Printf.sprintf
        "SELECT * FROM district_municipalities(
          '%s',
          '#000000',
          '10',
          'blue',
          '0.5',
          %d)"
        district precision
    in
    Caqti_type.(unit ->? string) query

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
    Caqti_type.(unit ->? string) query

  let parish ~parish ~precision =
    let query =
      Printf.sprintf
        "SELECT * FROM parish(
          '%s',
          '#000000',
          '0.1',
          'blue',
          '0.5',
          %d)"
        parish precision
    in
    Caqti_type.(unit ->? string) query
end
