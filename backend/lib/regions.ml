open Caqti_request.Infix

module Regions = struct
  let districts _ =
    let query =
      "SELECT DISTINCT distrito_ilha
       FROM cont_freguesias"
    in
    Caqti_type.(unit ->* string) query

  let municipalities district =
    let query = Printf.sprintf
      "SELECT DISTINCT municipio
       FROM cont_freguesias
       WHERE distrito_ilha = '%s'"
       district
    in
    Caqti_type.(unit ->* string) query

  let parishes municipality =
    let query = Printf.sprintf
      "SELECT DISTINCT freguesia
      FROM cont_freguesias
      WHERE municipio = '%s'"
       municipality
    in
    Caqti_type.(unit ->* string) query
end
