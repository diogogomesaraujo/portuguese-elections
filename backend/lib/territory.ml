open Caqti_request.Infix

module Territory = struct
  let code ~district ~municipality ~parish =
    let query = Printf.sprintf
      "SELECT *
      FROM wh.resolve_match_territory('%s', '%s', '%s');"
      parish municipality district
    in
    Caqti_type.(unit ->? string) query
end
