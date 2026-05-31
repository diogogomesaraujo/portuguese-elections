open Caqti_request.Infix

module Table = struct
  type t =
    { header: string array
    ; data: string list list }

let generic =
  let query =
    "SELECT freguesia, municipio, distrito_ilha, nuts3 FROM cont_freguesias ORDER BY nuts3"
  in
  ["Freguesia"; "Município"; "Distrito/Ilha"; "Zona"],
  Caqti_type.(unit ->* t4 string string string string) query
end
