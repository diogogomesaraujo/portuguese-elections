open Caqti_request.Infix

module Map = struct
  let country_districts _ ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM country(
          '%s',
          %s,
          '%s',
          NULL,
          '#000000',
          '500',
          '#cccccc',
          '0.85',
          %d)"
        election_type
        election_year
        office
        precision
    in
    Caqti_type.(unit ->? string) query

  let district_municipalities district ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM district_municipalities(
          '%s',
          %s,
          '%s',
          '%s',
          NULL,
          '#000000',
          '50',
          '#cccccc',
          '0.85',
          %d)"
        election_type
        election_year
        office
        district
        precision
    in
    Caqti_type.(unit ->? string) query

  let municipality_parishes municipality ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM municipality_parishes(
          '%s',
          %s,
          '%s',
          '%s',
          NULL,
          '#000000',
          '10',
          '#cccccc',
          '0.85',
          %d)"
        election_type
        election_year
        office
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
