open Caqti_request.Infix

(*
  Caqti infix operators

  ->! decodes a single row
  ->? decodes zero or one row
  ->* decodes many rows
  ->. expects no row
*)

let sql_escape s =
  String.concat "''" (String.split_on_char '\'' s)

module Map = struct
  let country_districts _ ~precision =
    let query =
      Printf.sprintf
        "SELECT * FROM country(
          '#000000',
          '8',
          '#cccccc',
          '0.85',
          %d)"
        precision
    in
    Caqti_type.(unit ->? string) query

  let district_municipalities district ~precision =
    let district = sql_escape district in
    let query =
      Printf.sprintf
        "SELECT * FROM district_municipalities(
          '%s',
          '#000000',
          '4',
          '#cccccc',
          '0.85',
          %d)"
        district
        precision
    in
    Caqti_type.(unit ->? string) query

  let municipality_parishes municipality ~precision =
    let municipality = sql_escape municipality in
    let query =
      Printf.sprintf
        "SELECT * FROM municipality_parishes(
          '%s',
          '#000000',
          '1.5',
          '#cccccc',
          '0.85',
          %d)"
        municipality
        precision
    in
    Caqti_type.(unit ->? string) query

  let parish parish_name ~precision ~election_type ~election_year ~office =
    let parish_name = sql_escape parish_name in
    let election_type = sql_escape election_type in
    let office = sql_escape office in
    let query =
      Printf.sprintf
        "SELECT * FROM parish(
          '%s',
          %d,
          '%s',
          '%s',
          '#000000',
          '0.5',
          '#cccccc',
          '0.85',
          %d)"
        election_type
        election_year
        office
        parish_name
        precision
    in
    Caqti_type.(unit ->? string) query
end
