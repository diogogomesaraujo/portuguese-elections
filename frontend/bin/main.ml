open Frontend.Test
open! Virtual_dom
open! Bonsai_web
open! Core
open Frontend.Test

let root_component = Bonsai.const bulleted_list

let () =
  Async_js.init ();
  Bonsai_web.Start.start root_component
