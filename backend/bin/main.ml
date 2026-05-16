open Backend.Pg
open Api
open Lwt.Infix
open Lwt.Syntax

let () =
  let connection = Lwt_main.run (Pg.connect ~uri: "postgresql://localhost:5432/spatial" ()) in
  Api.run ~connection
