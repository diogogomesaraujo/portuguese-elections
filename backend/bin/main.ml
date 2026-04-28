open Backend.Map
open Backend.Pg

let () =
  let query = "SELECT st_astext(st_simplifypreservetopology(geom, 60)) FROM  cont_freguesias WHERE distrito_ilha = 'Braga';" in
  let connection = Map.connect in
  let p = Map.from_query ~connection ~query in

  Map.draw
    ~polygon: p
    ~name: "plot.svg"
    ~format: "svgcairo"
    ()
