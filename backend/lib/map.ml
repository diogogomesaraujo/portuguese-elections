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
        "SELECT * FROM country(
          '#000000',
          '100000',
          'blue',
          '0.5',
          %d)"
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

  let municipality_parishes municipality ~precision =
    let query =
      Printf.sprintf
        "SELECT * FROM municipality_parishes(
          '%s',
          '#000000',
          '3',
          'blue',
          '0.5',
          %d)"
        municipality precision
    in
    Caqti_type.(unit ->? string) query

  let parish parish ~precision =
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
