open Caqti_request.Infix
open Req

module Map = struct
  let get ~code ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM map_territory(
          %s,
          %s,
          %s,
          %s,
          NULL,
          '#0F1A1D',
          '50',
          '#cccccc',
          '0.95',
          %d)"
        (Req.to_param (election_type, true))
        (Req.to_param (election_year, false))
        (Req.to_param (office, true))
        (Req.to_param (code, true))
        precision
    in
    Dream.log "%s" query;
    Caqti_type.(unit ->? string) query
end
