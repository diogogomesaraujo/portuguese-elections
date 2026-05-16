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

  let map ~uri ?arguments ?config () =
    let color, stroke, stroke_width =
      match config with
      | Some c -> c
      | None -> "pink", "purple", 5
  in

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
        (match Yojson.Safe.from_string val_opt with
        | `String s -> set_svg s
        | _ -> set_svg "")
      | Error e ->
        "failed to request image xD" |> set_svg
    in

    let%sub () =
      Bonsai_extra.exactly_once effect
    in

    let%arr svg = svg in

    let svg = Printf.sprintf
      "<svg
        xmlns=\"http://www.w3.org/2000/svg\"
        width=\"400\"
        height=\"400\"
        viewBox=\"-31500 -206200 3000 3000\"
        >
        <path
          style=\"fill:%s;stroke:%s;stroke-width:%d\"
          d=\"%s\"/>
      </svg>"
      color stroke stroke_width svg
    in

    Vdom.Node.div [
      Vdom.Node.inner_html
        ~tag:"div"
        ~attrs:[]
        ~this_html_is_sanitized_and_is_totally_safe_trust_me: svg
        ()
    ]

    let parish ~parish ~uri () =
      let uri = uri ^ "/map/parish/" ^ parish in
      map ~uri ()
end
