open Caqti_request.Infix

module Elections = struct
  let election_types _ =
    let query =
      "
      SELECT DISTINCT lower(election_type)
      FROM wh.dim_election
      ORDER BY lower(election_type);
      "
    in
    Caqti_type.(unit ->* string) query

  let election_years election_type =
    let query =
      Printf.sprintf
        "
        SELECT DISTINCT election_year
        FROM wh.dim_election
        WHERE lower(election_type) = lower('%s')
        ORDER BY election_year DESC;
        "
        election_type
    in
    Caqti_type.(unit ->* string) query

  let offices election_type =
    let query =
      Printf.sprintf
        "
        SELECT DISTINCT
            lower(o.office_name)
        FROM wh.fact_turnout ft
        JOIN wh.dim_election e
          ON e.election_key = ft.election_key
        JOIN wh.dim_office o
          ON o.office_key = ft.office_key
        WHERE lower(e.election_type) = lower('%s')
        ORDER BY lower(o.office_name);
        "
        election_type
    in
    Caqti_type.(unit ->* string) query
end
