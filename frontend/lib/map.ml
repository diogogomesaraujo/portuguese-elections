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
      ; offices:        (string * string) list }
      [@@deriving sexp, equal]

    let default =
      { districts      = [not_selected]
      ; municipalities = [not_selected]
      ; parishes       = [not_selected]
      ; election_years = [not_selected]
      ; election_types = [not_selected]
      ; offices        = [not_selected, not_selected] }

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

    let offices ~uri =
      let%bind.Effect res =
        Bonsai_web.Effect.of_deferred_fun
          (fun uri -> Api.get ~uri ()) uri in

      [not_selected, not_selected] @ (match res with
      | Ok res ->
        (match Yojson.Safe.from_string res with
        | `List [`List names; `List codes] ->
          (match List.map2
            names codes
            ~f: (fun name code -> name |> consume, code |> consume) with
          | Unequal_lengths -> []
          | Ok l -> l)
        | _ -> []
        )
      | _ -> []) |> Effect.return

    let office_names l =
      List.map l ~f:(fun (name, _) -> name)
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

          let f = Fn.id

          let form_for_field : type a. a Typed_field.t -> a F.t Computation.t = function
            | Typed_field.District ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  List.map field_options.districts ~f)
                ~to_string:f

            | Typed_field.Municipality ->
              F.Elements.Dropdown.list
                (module String)
              (let%map field_options = field_options in
                List.map field_options.municipalities ~f)
              ~to_string:f

            | Typed_field.Parish ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  List.map field_options.parishes ~f)
                ~to_string:f

            | Typed_field.Office ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  field_options.offices |> FieldOptions.office_names |> List.map ~f)
                ~to_string:f

            | Typed_field.Election_type ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  List.map field_options.election_types ~f)
                ~to_string:f

            | Typed_field.Election_year ->
              F.Elements.Dropdown.list
                (module String)
                (let%map field_options = field_options in
                  List.map field_options.election_years ~f)
                ~to_string:f
          ;;
        end)
  end

  module PlotType = struct
    let uri_of ~uri ~name ~election_type ~election_year ~office ~territory_code =
      let base = uri ^ "/plot/" ^ name in
      Printf.sprintf
        "%s/%s/%s/%s/%s"
        base
        election_type
        election_year
        office
        territory_code

    let uri_of_rise_and_fall ~uri ~election_type ~office ~territory_code =
      let base = uri ^ "/plot/riseandfall" in

      let base_with_args = Printf.sprintf
        "%s/%s/%s/%s"
        base
        election_type
        office
        territory_code
      in

      base_with_args ^ "/votes/rise",
      base_with_args ^ "/votes/fall",
      base_with_args ^ "/seats/rise",
      base_with_args ^ "/seats/fall"
  end

  module Territory = struct
    type t =
      { code: string }
      [@@deriving sexp, equal]

    let default = { code = "1" }

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
        | _ -> ""
      in

      match Yojson.Safe.from_string res with
      | `String code ->
        Effect.return { code = code }
      | _ -> Effect.return { code = res }
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
        F.value current_form |> Or_error.ok_exn
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
        FieldOptions.offices ~uri: (uri ^ "/election/offices/"
                            ^ String.lowercase form_state.election_type)
      in

      set_field_options
        { districts
        ; municipalities
        ; parishes
        ; offices = offices
        ; election_years
        ; election_types }
    in

    let%sub fetch_territory =
      let%arr form = form
        and set_territory = set_territory
      in

      let f =
        F.value form |> Or_error.ok_exn
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
      let f = F.value form |> Or_error.ok_exn in

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

    let uris =
      let%map territory_state = territory_state
      and field_options_state = field_options_state
      and form = form in
      let f = F.value form |> Or_error.ok_exn in

      let office =
        match List.find field_options_state.offices
          ~f:(fun (n, c) -> String.equal n f.office) with
        | Some (name, code) ->
          code
        | None              ->
          not_selected
      in

      PlotType.uri_of
        ~uri
        ~name: "treemap"
        ~election_type: f.election_type
        ~election_year: f.election_year
        ~office
        ~territory_code: territory_state.code,

      PlotType.uri_of
        ~uri
        ~name: "distribution"
        ~election_type: f.election_type
        ~election_year: f.election_year
        ~office
        ~territory_code: territory_state.code
    in

    let treemap_uri =
      let%map uri, _ = uris in
      uri
    in

    let distribution_uri =
      let%map _, uri = uris in
      uri
    in

    let%sub treemap =
      make ~uri: treemap_uri ()
    in

    let%sub distribution =
      make ~uri: distribution_uri ()
    in

    let rise_and_fall_uris =
      let%map territory_state = territory_state
      and field_options_state = field_options_state
      and form = form in
      let f = F.value form |> Or_error.ok_exn in

      let office =
        match List.find field_options_state.offices
          ~f:(fun (n, c) -> String.equal n f.office) with
        | Some (name, code) ->
          code
        | None              ->
          not_selected
      in

      PlotType.uri_of_rise_and_fall
        ~uri
        ~election_type: f.election_type
        ~office
        ~territory_code: territory_state.code
    in

    let rise_votes_uri =
      let%map vr, _, _, _ = rise_and_fall_uris in
      vr
    in

    let rise_seats_uri =
      let%map _, vf, _, _ = rise_and_fall_uris in
      vf
    in

    let fall_votes_uri =
      let%map _, _, sr, _ = rise_and_fall_uris in
      sr
    in

    let fall_seats_uri =
      let%map _, _, _, sf = rise_and_fall_uris in
      sf
    in

    let%sub rise_votes =
      make ~uri: rise_votes_uri ()
    in

    let%sub rise_seats =
      make ~uri: rise_seats_uri ()
    in

    let%sub fall_votes =
      make ~uri: fall_votes_uri ()
    in

    let%sub fall_seats =
      make ~uri: fall_seats_uri ()
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
      and treemap = treemap
      and rise_votes = rise_votes
      and rise_seats = rise_seats
      and fall_votes = fall_votes
      and fall_seats = fall_seats
      and distribution = distribution
    in

    let v =
      F.value_or_default form
        ~default: Selected.default
    in

    let open Css_gen in

    let box_style =
      flex_container
        ~direction: `Row
        ~wrap: `Wrap()
        ~justify_content: `Center
      @> width (Length.percent100)
      |> Vdom.Attr.style
    in

    Vdom.Node.div
      [ h1 [ text "\\dt portuguese_elections.*" ]
      ; F.view_as_vdom form
      (* ;  Vdom.Node.button
        ~attrs: [Vdom.Attr.on_click (fun _ ->
                                      set_territory territory_state)]
          [ Vdom.Node.text "Query" ] *)
      ; map
      ; h2 [ text "Data Analysis" ]
      ; h3 [ text (Printf.sprintf "Year-specific (%s)" v.election_year) ]
      ; div [treemap; distribution] ~attrs: [box_style]
      ; h3 [ text "Multi-year" ]
      ; div [rise_votes ; rise_seats ; fall_votes ; fall_seats] ~attrs: [box_style]
      ]
end
