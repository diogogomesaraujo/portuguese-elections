open! Core
open Virtual_dom
open Virtual_dom_svg
open Api
open Bonsai
open! Bonsai_web
open Bonsai.Let_syntax
open Ppx_css

module Table = struct
  module State = struct
    type t =
      { header: string list
      ; data:   string list list }
      [@@deriving sexp, equal]

    let empty = { header = []; data = [] }
  end

  let get ~uri ?arguments () =
    Api.get ?arguments ~uri ()

  let make ~uri =
    let%bind.Effect res =
      Bonsai_web.Effect.of_deferred_fun
        (fun uri -> get ~uri ()) uri
    in

    (match res with
    | Ok res ->
      (match Yojson.Safe.from_string res with
      | `List res ->
        let l = List.filter_map
          res
          ~f: (fun json ->
            match json with
            | `List l ->
              Some (List.filter_map
                l
                ~f:(fun e ->
                  match e with
                  | `String e -> Some e
                  | _ -> None)
                )
            | _ -> None)
        in
        (match l with
        | header::data -> { State.header = header
                          ; State.data = data }
        | _ -> State.empty)
      | _ -> State.empty)
    | _  -> State.empty) |> Effect.return

  let card ~uri () =
    let open Vdom.Node in

    let%sub table_state, set_table =
      Bonsai.state
        (module State)
        ~default_model: State.empty
    in

    let%sub effect =
      let%arr set_table = set_table in
      let%bind.Effect t = make ~uri in
      set_table t
    in

    let%sub () =
      Bonsai_extra.exactly_once effect
    in

    let%arr t = table_state in

    let thead = List.map t.header ~f: (
      fun h -> th [ text h ]
    ) |> tr |> List.return |> thead in

    let tbody =
      List.transpose t.data |> Option.value ~default: [] |> List.map
        ~f:(fun l ->
          let l = List.map l ~f: (
            fun e -> td [ text e ]
          ) in
        tr l)
      |> tbody
    in
    table [ thead; tbody ]
end
