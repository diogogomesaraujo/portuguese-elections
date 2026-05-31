open Caqti_request.Infix

module Regions = struct
  let districts _ =
    let query =
      "SELECT DISTINCT territory_name
       FROM wh.dim_territory
       WHERE territory_level = 'district'"
    in
    Caqti_type.(unit ->* string) query

  let municipalities district =
    let query = Printf.sprintf
      "SELECT DISTINCT territory_name
       FROM wh.dim_territory
       WHERE parent_name = '%s' AND territory_level = 'municipality'"
       district
    in
    Caqti_type.(unit ->* string) query

  let parishes municipality =
    let query = Printf.sprintf
      "SELECT DISTINCT territory_name
      FROM wh.dim_territory
      WHERE parent_name = '%s' AND territory_level = 'parish'"
       municipality
    in
    Caqti_type.(unit ->* string) query
end
