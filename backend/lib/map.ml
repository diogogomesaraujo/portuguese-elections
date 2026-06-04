open Caqti_request.Infix
open Req

module Map = struct
  let get ~key ~precision ~election_type ~election_year ~office =
    let query =
      Printf.sprintf
        "SELECT * FROM map_territory(
          %s,
          %s,
          %s,
          %s,
          NULL,
          '#162620',
          '50',
          '#0F1A1D',
          '1.0',
          %d)"
        (Req.to_param (election_type, true))
        (Req.to_param (election_year, false))
        (Req.to_param (office, true))
        (Req.to_param (key, false))
        precision
    in
    Dream.log "%s" query;
    Caqti_type.(unit ->? string) query
end
