open Pg
open Parse
open Plplot

module Map = struct
  let connect = new Postgresql.connection ~conninfo:"host=localhost port=5432 dbname=spatial user=diogoaraujo" ()

  let get_polygons (c: Postgresql.connection) query =
    c#send_query query;
    Array.map (fun r -> Array.map (
      fun c ->
      parse c
    ) r) (fetch_single_result c)#get_all

  let get_pol_xy pol =
    let (x, y) = List.fold_left
      (fun (acc_x, acc_y) p' ->
        let x_to_add, y_to_add = List.fold_left
        (fun (x', y') (x_to_add, y_to_add) ->
          (x' @ [x_to_add], y' @ [y_to_add])
        ) ([],[]) p'
        in (acc_x @ x_to_add, acc_y @ y_to_add)
      ) ([], []) pol
    in (Array.of_list x, Array.of_list y)

  let get_wkt_xy_l (pol: wkt_term) =
    match pol with
    | Polygon p ->
      [get_pol_xy p]
    | Multipolygon p ->
      List.map (fun p' -> get_pol_xy p') p

  let get_xy (pols_l_l: wkt_term array array) =
    Array.fold_left (fun acc p_l ->
      acc @ (Array.fold_left (
        fun acc' p -> acc' @ get_wkt_xy_l p
      ) [] p_l)
    ) [] pols_l_l

  let get_xy_min_max (x, y) =
    let min_max a = Array.fold_left (
      fun (mi, ma) a' ->
        (min mi a', max ma a')
    ) (Float.max_float, 0.) a in
    let (min_x, max_x) = min_max x in
    let (min_y, max_y) = min_max y in
    (min_x, max_x, min_y, max_y)

  let get_min_max l =
    List.fold_left (
      fun (min_x, max_x, min_y, max_y) xy ->
        let (min_x', max_x', min_y', max_y') = get_xy_min_max xy in
        (min min_x min_x', max max_x max_x', min min_y min_y', max max_y max_y')
    ) (Float.max_float, 0., Float.max_float, 0.) l

  let fill l =
    List.iter (
      fun (x, y) -> plfill x y;
    ) l

  let outline l =
    List.iter (
      fun (x, y) -> plline x y;
    ) l

  let draw p () =
    let l = get_xy p in
    let (xmin, xmax, ymin, ymax) = get_min_max l in

    plparseopts Sys.argv [PL_PARSE_FULL];

    plinit ();

    plenv xmin xmax ymin ymax 0 0 ;

    plcol0 5;
    fill l;

    plcol0 10;
    outline l;

    plend ();

end
