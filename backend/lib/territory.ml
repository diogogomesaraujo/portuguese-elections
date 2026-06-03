open Caqti_request.Infix
open Req

module Territory = struct
  let key ~district ~municipality ~parish =
    let query = Printf.sprintf
      "SELECT *
      FROM wh.resolve_match_territory(%s, %s, %s);"
      (Req.to_param (parish, true))
      (Req.to_param (municipality, true))
      (Req.to_param (district, true))
    in

    Dream.log "%s" query;

    Caqti_type.(unit ->? string) query
end
