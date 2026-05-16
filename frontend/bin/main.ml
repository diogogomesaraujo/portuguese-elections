open! Virtual_dom
open! Bonsai_web
open Frontend.Api
open Frontend.Map

let () =
  Async_js.init ();
  let root_component =
    Map.parish ~parish: "Tadim" ~uri: "http://localhost:8080" ()
  in
  Bonsai_web.Start.start root_component
