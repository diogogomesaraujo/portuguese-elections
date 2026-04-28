open Frontend.Table
open! Virtual_dom
open! Bonsai_web
open! Core

let () =
  Async_js.init ();
  let root_component = Bonsai.const table in
  Bonsai_web.Start.start root_component
