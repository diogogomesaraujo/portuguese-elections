open Caqti_request.Infix

module Elections = struct
  let election_types =
    let query =
      "SELECT DISTINCT territory_name
       FROM wh.dim_territory
       WHERE territory_level = 'district'"
    in
    Caqti_type.(unit ->* string) query

  let election_years =
    let query =
      "SELECT DISTINCT territory_name
       FROM wh.dim_territory
       WHERE territory_level = 'district'"
    in
    Caqti_type.(unit ->* int) query

  let offices =
    let query =
      "SELECT DISTINCT territory_name
       FROM wh.dim_territory
       WHERE territory_level = 'district'"
    in
    Caqti_type.(unit ->* string) query
end
