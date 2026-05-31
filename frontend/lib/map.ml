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

  let not_selected = "Not selected"

  let not_selected_year = 2023

  module FieldOptions = struct
    type t =
      { districts:      string list
      ; municipalities: string list
      ; parishes:       string list
      ; election_years: int    list
      ; election_types: string list
      ; offices:        string list }
      [@@deriving sexp, equal]

    let default =
      { districts      = [not_selected]
      ; municipalities = [not_selected]
      ; parishes       = [not_selected]
      ; election_years = [not_selected_year]
      ; election_types = [not_selected]
      ; offices        = [not_selected] }

    let all ~uri =
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> Api.get ~uri ()) uri
      in

      [not_selected] @ (match res with
      | Ok res ->
        (match Yojson.Safe.from_string res with
        | `List regions ->
          List.filter_map
            regions
            ~f: (fun json ->
              match json with
              | `String r -> Some r
              | _ -> None)
        | _ -> []
        )
      | _ -> []) |> Effect.return

  let all_int ~uri =
    let%bind.Effect res =
      Bonsai_web.Effect.of_deferred_fun
        (fun uri -> Api.get ~uri ()) uri
    in

    [not_selected_year] @ (match res with
    | Ok res ->
      (match Yojson.Safe.from_string res with
      | `List regions ->
        List.filter_map
          regions
          ~f: (fun json ->
            match json with
            | `Int r -> Some r
            | _ -> None)
      | _ -> []
      )
    | _ -> []) |> Effect.return
end

  module Selected = struct
    type t =
      { office:          string
      ; election_type:   string
      ; election_year:   int
      ; district:        string
      ; municipality:    string
      ; parish:          string
      }
      [@@deriving sexp, equal, typed_fields]

    let default =
      { district      = not_selected
      ; municipality  = not_selected
      ; parish        = not_selected
      ; office        = not_selected
      ; election_type = not_selected
      ; election_year = not_selected_year }

    let form ~(field_options: FieldOptions.t Value.t) =
      F.Typed.Record.make
        (module struct
          module Typed_field = Typed_field

          let label_for_field = `Inferred

          let form_for_field : type a. a Typed_field.t -> a F.t Computation.t = function
            | Typed_field.District ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  field_options.districts)
            | Typed_field.Municipality ->
              F.Elements.Dropdown.list
                (module String)
              (let%map field_options = field_options in
                field_options.municipalities)
            | Typed_field.Parish ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  field_options.parishes)
            | Typed_field.Office ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  field_options.offices)
            | Typed_field.Election_type ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  field_options.election_types)
            | Typed_field.Election_year ->
              F.Elements.Dropdown.list
                (module Int)
                (let%map field_options = field_options in
                  field_options.election_years)
          ;;
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

  let get ~uri ?arguments () =
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
          (fun uri -> get ~uri ?arguments ()) uri
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

    let%sub field_options_state, set_field_options =
      Bonsai.state
        (module FieldOptions)
        ~default_model: FieldOptions.default
    in

    let%sub form =
      Selected.form ~field_options: field_options_state
    in

    let%sub map_type =
      let%arr form = form
      in

      match F.value form with
      | Ok f when not (String.equal f.parish not_selected) ->
        MapType.Parish f.parish
      | Ok f when not (String.equal f.municipality not_selected) ->
        MapType.Municipality f.municipality
      | Ok f when not (String.equal f.district not_selected) ->
        MapType.District f.district
      | _ -> MapType.Country
    in

    let%sub fetch_field_options =
      let%arr form = form
        and set_field_options = set_field_options
      in

      let form_state =
        match F.value form with
        | Ok f -> f
        | _    -> Selected.default
      in

      let%bind.Effect parishes =
        FieldOptions.all ~uri: (uri ^ "/regions/parishes/"
                            ^ form_state.municipality)
      in

      let%bind.Effect municipalities =
        FieldOptions.all ~uri: (uri ^ "/regions/municipalities/"
                            ^ form_state.district)
      in

      let%bind.Effect districts =
        FieldOptions.all ~uri: (uri ^ "/regions/districts/_")
      in

      let%bind.Effect election_years =
        FieldOptions.all_int ~uri: (uri ^ "/election/years/"
                            ^ String.lowercase form_state.election_type)
      in

      let%bind.Effect election_types =
        FieldOptions.all ~uri: (uri ^ "/election/types/_")
      in

      let%bind.Effect offices =
        FieldOptions.all ~uri: (uri ^ "/election/offices/"
                            ^ String.lowercase form_state.election_type)
      in

      set_field_options
        { districts
        ; municipalities
        ; parishes
        ; offices
        ; election_years
        ; election_types }
    in

    let uri =
      let%map map_state = map_state in
      MapType.uri_of ~uri map_state
    in

    let%sub map =
      map ~uri ()
    in

    let%sub () = Bonsai.Edge.on_change
      (module Selected)
      (let%map form = form in F.value form |> Or_error.ok_exn)
      ~callback:
        (let%map effect = fetch_field_options in
          fun _ -> effect)
    in

    let%arr form = form
    and set_map = set_map
    and map_type = map_type
    and map = map in

    Vdom.Node.div
      [ F.view_as_vdom form
      ; Vdom.Node.sexp_for_debugging
        ([%sexp_of: Selected.t Or_error.t] (F.value form))
      ;  Vdom.Node.button
        ~attrs: [Vdom.Attr.on_click (fun _ ->
                                      set_map map_type)]
          [ Vdom.Node.text "Update" ]
      ; map
      ]
end
