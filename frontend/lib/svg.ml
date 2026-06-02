open! Core
open Virtual_dom
open Virtual_dom_svg
open Api
open Bonsai
open! Bonsai_web
open Bonsai.Let_syntax
open Ppx_css

module Svg = struct
  let make ~uri ?arguments  () =
    let%sub svg, set_svg =
      Bonsai.state (module String) ~default_model:""
    in

    let%sub effect =
      let%arr set_svg = set_svg
      and uri = uri in
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> Api.get ~uri ?arguments ()) uri
      in

      match res with
      | Ok val_opt ->
        (match Yojson.Safe.from_string val_opt with
        | `String s -> set_svg s
        | _ -> set_svg "")
      | Error e ->
        "failed to request image xD" |> set_svg
    in

    let%sub () =
      Bonsai.Edge.on_change
        (module String) uri
        ~callback:
          (let%map effect = effect in
              fun _ -> effect)
    in

    let%arr svg = svg in

    Vdom.Node.div [
      Vdom.Node.inner_html
        ~tag: "div"
        ~attrs:[]
        ~this_html_is_sanitized_and_is_totally_safe_trust_me: svg
        ()
    ]
end
