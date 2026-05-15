open Core
open Virtual_dom
open Virtual_dom_svg
open Api
open Bonsai
open Bonsai_web
open Bonsai.Let_syntax

module Map = struct
  let get_map ~uri ?arguments () =
    Api.get ?arguments ~uri ()

  let map ~uri ?arguments () =
    let%sub svg, set_svg =
      Bonsai.state (module String) ~default_model:""
    in

    let%sub effect =
      let%arr set_svg = set_svg in
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> get_map ~uri ?arguments ()) uri
      in

      match res with
      | Ok val_opt ->
        set_svg val_opt
      | Error e ->
        "failed to request image xD" |> set_svg
    in

    let%sub () =
      Bonsai_extra.exactly_once effect
    in

    let%arr svg = svg in

    Vdom.Node.div [
      Vdom.Node.inner_html
        ~tag:"svg"
        ~attrs:[]
        ~this_html_is_sanitized_and_is_totally_safe_trust_me: svg
        ()
    ]

    let district ~district ~uri () =
      let uri = uri ^ "/map/district/" ^ district in
      map ~uri ()
end
