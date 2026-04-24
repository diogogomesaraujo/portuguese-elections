open Virtual_dom

let bulleted_list : Vdom.Node.t =
  let open Vdom.Node in
  div
    [ h3 [ text "Norwegian Pancakes" ]
    ; ul
        [ li [ text "3 eggs" ]
        ; li [ text "2 cups of milk" ]
        ; li [ text "1 cup of flour" ]
        ]
    ]
