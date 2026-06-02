open! Core
open Virtual_dom
open Virtual_dom_svg
open Api
open Bonsai
open! Bonsai_web
open Bonsai.Let_syntax
open Ppx_css
open Svg

module Map = struct
  module F = Bonsai_web_ui_form

  let not_selected = "Not selected"

  module FieldOptions = struct
    type t =
      { districts:      string list
      ; municipalities: string list
      ; parishes:       string list
      ; election_years: string list
      ; election_types: string list
      ; offices:        string list }
      [@@deriving sexp, equal]

    let default =
      { districts      = [not_selected]
      ; municipalities = [not_selected]
      ; parishes       = [not_selected]
      ; election_years = [not_selected]
      ; election_types = [not_selected]
      ; offices        = [not_selected] }

    let rec consume : Yojson.Safe.t -> string = function
      | `String s -> s
      | s -> Yojson.Safe.to_string s

    let all ~uri =
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> Api.get ~uri ()) uri in

      [not_selected] @ (match res with
      | Ok res ->
        (match Yojson.Safe.from_string res with
        | `List regions ->
          List.filter_map
            regions
            ~f: (fun json -> Some (json |> consume))
        | _ -> []
        )
      | _ -> []) |> Effect.return
end

  module Selected = struct
    type t =
      { election_type:   string
      ; election_year:   string
      ; office:          string

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
      ; election_year = not_selected }

    let form ~(field_options: FieldOptions.t Value.t) =
      F.Typed.Record.make
        (module struct
          module Typed_field = Typed_field

          let label_for_field = `Computed (fun field ->
            Typed_field.name field
            |> String.capitalize
            |> String.substr_replace_all ~pattern:"_" ~with_:" ")

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
                (module String)
                (let%map field_options = field_options in
                  field_options.election_years)
          ;;
        end)
  end

  module PlotType = struct
    type t =
      | Treemap
      [@@deriving sexp, equal]

    let uri_of ~uri ~election_type ~election_year ~office ~territory_code ~t =
      let base =
        match t with
        | Treemap -> uri ^ "/plot/treemap"
      in

      Printf.sprintf
        "%s/%s/%s/%s/%s"
        base
        election_type
        election_year
        office
        territory_code
  end

  module Territory = struct
    type t =
      { code: string }
      [@@deriving sexp, equal]

    let default = { code = "PT" }

    let uri_of ~uri ~code ~election_type ~election_year ~office =
      Printf.sprintf
        "%s/map/%s/%s/%s/%s"
        uri
        code
        election_type
        election_year
        office

    let get ~uri =
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> Api.get ~uri ()) uri
      in

      let res =
        match res with
        | Ok res -> res
        | _ -> "upsie"
      in

      match Yojson.Safe.from_string res with
      | `String code ->
        Effect.return { code = code }
      | _ -> Effect.return default
  end

  let make = Svg.make

  let card ~uri () =
    let open Vdom.Node in
    let%sub territory_state, set_territory =
      Bonsai.state
        (module Territory)
        ~default_model: Territory.default
    in

    let%sub field_options_state, set_field_options =
      Bonsai.state
        (module FieldOptions)
        ~default_model: FieldOptions.default
    in

    let%sub form =
      Selected.form ~field_options: field_options_state
    in

    let%sub fetch_field_options =
      let%arr current_form = form
        and set_field_options = set_field_options
      in

      let form_state =
        F.value_or_default current_form ~default: Selected.default
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
        FieldOptions.all ~uri: (uri ^ "/election/years/"
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

    let%sub fetch_territory =
      let%arr form = form
        and set_territory = set_territory
      in

      let f =
        F.value_or_default form ~default: Selected.default
      in

      let uri = Printf.sprintf
        "%s/territory/%s/%s/%s"
        uri f.district f.municipality f.parish
      in

      let%bind.Effect territory = Territory.get ~uri in

      set_territory territory
    in

    let map_uri =
      let%map territory_state = territory_state
      and form = form in
      let f = F.value_or_default form ~default: Selected.default in

      Territory.uri_of
        ~uri
        ~code:          territory_state.code
        ~election_type: f.election_type
        ~election_year: f.election_year
        ~office:        f.office
    in

    let%sub map =
      make ~uri: map_uri ()
    in

    let plot_uri =
      let%map territory_state = territory_state
      and form = form in
      let f = F.value_or_default form ~default: Selected.default in

      PlotType.uri_of
        ~uri
        ~election_type: f.election_type
        ~election_year: f.election_year
        ~office:        f.office
        ~territory_code: territory_state.code
        ~t: Treemap
    in

    let%sub plot =
      make ~uri: plot_uri ()
    in

    let%sub () = Bonsai.Edge.on_change'
      (module Selected)
      (let%map form = form in F.value form |> Or_error.ok_exn)
      ~callback:
        (let%map effect = fetch_field_options
          and form = form
        in
          fun prev current ->
            match prev with
            | Some prev ->
              (match String.equal prev.Selected.district current.Selected.district,
                String.equal prev.municipality current.municipality with
              | false, _ -> F.set form
                { current with municipality = not_selected; parish = not_selected }
              | _, false -> F.set form
                { current with parish = not_selected }
              | _ -> Effect.return ())
            | _ -> Effect.return ()
         )
    in

    let%sub () = Bonsai.Edge.on_change
      (module Selected)
      (let%map form = form in F.value form |> Or_error.ok_exn)
      ~callback:
        (let%map effect =
          fetch_field_options
        in
          fun _ -> effect)
    in

    let%sub () = Bonsai.Edge.on_change
      (module Selected)
      (let%map form = form in F.value form |> Or_error.ok_exn)
      ~callback:
        (let%map effect =
          fetch_territory
        in
          fun _ -> effect)
    in

    let%arr form = form
      and set_territory = set_territory
      and territory_state = territory_state
      and map = map
      and plot = plot
    in

    Vdom.Node.div
      [ h1 [text "\\dt portuguese_elections.*"]
      ; F.view_as_vdom form
      (* ;  Vdom.Node.button
        ~attrs: [Vdom.Attr.on_click (fun _ ->
                                      set_territory territory_state)]
          [ Vdom.Node.text "Query" ] *)
      ; map
      ; plot
      ]
end
