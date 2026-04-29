open Backend.Map
open Backend.Pg

let () =
  let p = Map.municipality_parishes
    ~municipality: "Braga"
    ~connection: Map.connect
  in Map.draw
    ~polygon: p
    ~name: "plot.svg"
    ~format: "svgcairo"
    ~outline_color: 5
    ~fill_color: 10
    ()
