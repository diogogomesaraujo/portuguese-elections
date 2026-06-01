open Cohttp_lwt_unix
let ( let* ) = Lwt.bind


module Req = struct
  let get ~uri =
    let* (resp, body) = Client.get (Uri.of_string uri) in
    let code = resp
                 |> Cohttp.Response.status
                 |> Cohttp.Code.code_of_status in
      if Cohttp.Code.is_success code
      then
        let* b = Cohttp_lwt.Body.to_string body in
        Lwt.return (Ok b)
      else
        Lwt.return (Error "upsie")
end
