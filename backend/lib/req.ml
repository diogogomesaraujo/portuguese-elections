open Cohttp_lwt_unix
let ( let* ) = Lwt.bind

module Req = struct
  let not_selected = "Not selected"

  let to_param = function
    | p, _ when String.equal p not_selected -> "NULL"
    | p, true -> "'" ^ p ^ "'"
    | p, _ -> p

  let get ~uri =
    let* (resp, body) = Client.get (Uri.of_string uri) in
    let code = resp
                 |> Cohttp.Response.status
                 |> Cohttp.Code.code_of_status in
      if Cohttp.Code.is_success code
      then
        Cohttp_lwt.Body.to_string body
      else
        Lwt.return "upsie"
end
