open Backend.Map
open Backend.Pg

let () =
  Array.iteri (fun i r -> Array.iteri (
    fun j c -> Printf.printf "%d, %d: %s\n" i j (show_wkt_term c)
  ) r) (Map.get_polygon Map.connect "SELECT st_astext(geom) FROM  cont_freguesias;")
