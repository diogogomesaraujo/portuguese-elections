open Api
open Backend.Map

let () =
  let config = Map.config
    ~format: "svgcairo"
    ~outline_color: 5
    ~fill_color: 10
  in
  Api.run ~connection: Map.connect ~config ()
