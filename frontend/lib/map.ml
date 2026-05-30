open! Core
open Virtual_dom
open Virtual_dom_svg
open Api
open Bonsai
open! Bonsai_web
open Bonsai.Let_syntax
open Ppx_css

module Map = struct
  module F = Bonsai_web_ui_form

  module Form = struct
    type t =
      { district:     string
      ; municipality: string
      ; parish:       string
      }
      [@@deriving typed_fields, sexp_of]

    let form_of_t : t F.t Computation.t =
      F.Typed.Record.make
          (module struct
            module Typed_field = Typed_field

            let label_for_field = `Inferred

            let form_for_field : type a. a Typed_field.t -> a F.t Computation.t = function
              | Typed_field.District     -> F.Elements.Textbox.string ()
              | Typed_field.Municipality -> F.Elements.Textbox.string ()
              | Typed_field.Parish       -> F.Elements.Textbox.string ()
          end)
  end

  module MapType = struct
    type t =
     | Country
     | District of string
     | Municipality of string
     | Parish of string
     [@@deriving sexp, equal]

    let uri_of ~uri = function
      | Country        -> uri ^ "/map/country/_"
      | District d     -> uri ^ "/map/district/" ^ d
      | Municipality m -> uri ^ "/map/municipality/" ^ m
      | Parish p       -> uri ^ "/map/parish/" ^ p
  end

  let get_map ~uri ?arguments () =
    Api.get ?arguments ~uri ()

  let map ~uri ?arguments  () =
    let%sub svg, set_svg =
      Bonsai.state (module String) ~default_model:""
    in

    let%sub effect =
      let%arr set_svg = set_svg
      and uri = uri in
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
      Bonsai.Edge.on_change
        (module String) uri
        ~callback:
          (let%map effect = effect in
              fun _ -> effect)
    in

    let%arr svg = svg in

    Vdom.Node.div [
      Vdom.Node.inner_html
        ~tag:"div"
        ~attrs:[]
        ~this_html_is_sanitized_and_is_totally_safe_trust_me: svg
        ()
    ]

  let card ~uri () =
    let open Vdom.Node in
    let%sub map_state, set_map =
      Bonsai.state
        (module MapType)
        ~default_model: Country
    in

    let%sub form  = Form.form_of_t in

    let%sub map_type =
      let%arr form = form in
      match F.value form with
      | Ok v when String.length v.parish <> 0 ->
        MapType.Parish v.Form.parish
      | Ok v when String.length v.municipality <> 0 ->
        MapType.Municipality v.Form.municipality
      | Ok v when String.length v.district <> 0 ->
        MapType.District v.Form.district
      | _ -> MapType.Country
    in

    let uri =
      let%map map_state = map_state in
      MapType.uri_of ~uri map_state
    in

    let%sub map = map ~uri () in

    let%arr form = form
    and set_map = set_map
    and map_type = map_type
    and map = map in

    Vdom.Node.div
      [ F.view_as_vdom form
      ; Vdom.Node.sexp_for_debugging ([%sexp_of: Form.t Or_error.t] (F.value form))
      ;  Vdom.Node.button
          ~attrs: [Vdom.Attr.on_click (fun _ -> set_map map_type)]
          [ Vdom.Node.text "Update" ]
      ; map
      ]
end
