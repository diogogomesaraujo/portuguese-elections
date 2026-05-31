open! Virtual_dom
open! Bonsai_web
open Frontend.Api
open Frontend.Map
open Frontend.Table

let () =
  Async_js.init ();
  let root_component =
    (* Map.card ~uri: "http://localhost:8080" () *)
    Table.card ~uri: "http://localhost:8080/table/generic" ()
  in
  Bonsai_web.Start.start root_component
