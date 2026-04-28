open Backend.Map
open Backend.Pg

let () =
  let p = Map.country_parishes
    ~connection: Map.connect
  in Map.draw
    ~polygon: p
    ~name: "plot.svg"
    ~format: "svgcairo"
    ()
