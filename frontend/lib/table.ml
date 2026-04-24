open! Core
open! Bonsai_web

type row =
  { id : int
  ; name : string
  ; age : int
  }

let basic_table rows =
  let open Vdom.Node in
  let thead = thead [ td [ text "id" ]; td [ text "name" ]; td [ text "age" ] ] in
  let tbody =
    rows
    |> List.map ~f:(fun { id; name; age } ->
      tr [ td [ textf "%d" id ]; td [ text name ]; td [ textf "%d" age ] ])
    |> tbody
  in
  table [ thead; tbody ]
;;

let table =
  basic_table
    [ { id = 0; name = "George Washington"; age = 67 }
    ; { id = 1; name = "Alexander Hamilton"; age = 47 }
    ; { id = 2; name = "Abraham Lincoln"; age = 56 }
    ]
;;
