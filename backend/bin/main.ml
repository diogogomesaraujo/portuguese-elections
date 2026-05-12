open Backend.Map
open Backend.Pg

let () =
  let p = Map.district_parishes
    ~district: "Porto"
    ~connection: Map.connect
  in Map.draw
    ~polygon: p
    ~name: "plot.svg"
    ~format: "svgcairo"
    ~outline_color: 5
    ~fill_color: 10
    ()
