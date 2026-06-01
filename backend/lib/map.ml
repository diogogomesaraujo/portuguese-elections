open Caqti_request.Infix

(*
  Caqti infix operators

  ->! decodes a single row
  ->? decodes zero or one row
  ->* decodes many rows
  ->. expects no row
*)

module Map = struct
  let country_districts _ ~precision ~election_type ~election_year ~office =
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

  let district_municipalities district ~precision ~election_type ~election_year ~office =
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

  let municipality_parishes municipality ~precision ~election_type ~election_year ~office =
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

  let parish parish ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM parish(
          '%s',
          %s,
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
        parish
        precision
    in
    Caqti_type.(unit ->? string) query
end
