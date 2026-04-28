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
    List.fold_left
      (fun (acc_x, acc_y) p' ->
        let x_to_add, y_to_add = List.fold_left
        (fun (x', y') (x_to_add, y_to_add) ->
          (x' @ [x_to_add], y' @ [y_to_add])
        ) ([],[]) p'
        in (acc_x @ x_to_add, acc_y @ y_to_add)
      ) ([], []) pol

  let get_wkt_xy (pol: wkt_term) =
    match pol with
    | Polygon p ->
      get_pol_xy p
    | Multipolygon p ->
      List.fold_left (fun (x, y) p' ->
        get_pol_xy p'
      ) ([],[]) p

  let get_xy pols =
    let (x, y) = Array.fold_left
      (fun (acc_x, acc_y) p ->
        let x_to_add, y_to_add = Array.fold_left
        (fun (x', y') p ->
          let (x_to_add', y_to_add') = get_wkt_xy p in
          (x' @ x_to_add', y' @ y_to_add')
        ) ([],[]) p
        in (acc_x @ x_to_add, acc_y @ y_to_add)
      ) ([], []) pols in
    (Array.of_list x, Array.of_list y)

  let get_xy_min_max (x, y) =
    let min_max a = Array.fold_left (
      fun (ma, mi) a' ->
        (max ma a', min mi a')
    ) (0., Float.max_float) a in
    let (max_x, min_x) = min_max x in
    let (max_y, min_y) = min_max y in
    (max_x, min_x, max_y, min_y)

  let draw p () =
    let (x, y) = get_xy p in
    let (xmax, xmin, ymax, ymin) = get_xy_min_max (x, y) in

    plparseopts Sys.argv [PL_PARSE_FULL];

    plinit ();

    plenv xmin xmax ymin ymax 0 0 ;

    plfill x y;

    plend ();

end
