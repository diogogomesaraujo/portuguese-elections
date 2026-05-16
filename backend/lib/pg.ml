open Caqti_driver_postgresql
open Lwt.Infix
open Lwt.Syntax

module Pg = struct
  let connect ~uri () =
    let%lwt conn = Caqti_lwt_unix.connect (Uri.of_string uri) in
    match conn with
    | Ok conn -> Lwt.return conn
    | Error e -> Caqti_error.show e |> failwith
end
