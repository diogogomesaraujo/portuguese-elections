open Backend.Map
open Backend.Pg

let () =
   Map.draw (Map.get_polygons Map.connect "SELECT st_astext(st_simplifypreservetopology(geom, 50)) FROM  cont_freguesias WHERE distrito_ilha = 'Braga';") ()
