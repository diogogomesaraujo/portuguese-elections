open Caqti_request.Infix

module Elections = struct
  let election_types _ =
    let query =
      "
      SELECT DISTINCT election_type
      FROM wh.dim_election
      ORDER BY election_type;
      "
    in
    Caqti_type.(unit ->* string) query

  let election_years election_type =
    let query =
      Printf.sprintf
        "
        SELECT DISTINCT election_year
        FROM wh.dim_election
        WHERE LOWER(election_type) = '%s'
        ORDER BY election_year DESC;
        "
        election_type
    in
    Caqti_type.(unit ->* int) query

  let offices election_type =
    let query =
      Printf.sprintf
        "
        SELECT DISTINCT
            o.office_name
        FROM wh.fact_turnout ft
        JOIN wh.dim_election e
          ON e.election_key = ft.election_key
        JOIN wh.dim_office o
          ON o.office_key = ft.office_key
        WHERE LOWER(e.election_type) = '%s'
        ORDER BY o.office_name;
        "
        election_type
    in
    Caqti_type.(unit ->* string) query
end
