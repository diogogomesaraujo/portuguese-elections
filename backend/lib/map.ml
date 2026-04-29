open Pg
open Parse
open Plplot

(** Module that represents a set of polygons that is retrieved from a PostGIS spatial database
to be drawn using plplot.*)
module Map = struct
  (** Type that represents a matrix of polygons.*)
  type t = wkt_term array array

  (** Constant value that determines the precision used to rasterize the map.*)
  let precision = 60

  (** Function that returns a PostgreSQL connection.*)
  let connect =
    new Postgresql.connection
      ~conninfo:"host=localhost port=5432 dbname=spatial user=diogoaraujo" ()

  (** Function that retrieves a map from the database according to a given query.*)
  let from_query ~(connection: Postgresql.connection) ~query =
    connection#send_query query;
    Array.map (fun r -> Array.map (
      fun c ->
      parse c
    ) r) (fetch_single_result connection)#get_all

  (** Function that returns all the parishes in Portugal.*)
  let country_parishes ~connection =
    let query =
      Printf.sprintf "SELECT st_astext(st_simplify(geom, %d)) FROM cont_freguesias;"
        precision in
    from_query ~connection ~query

  (** Function that returns all the parishes in a given district.*)
  let district_parishes ~district ~connection =
    let query =
      Printf.sprintf "SELECT st_astext(st_simplify(geom, %d)) FROM cont_freguesias WHERE distrito_ilha = '%s'"
        precision district in
    from_query ~connection ~query

  (** Function that returns all the parishes in a given municipality.*)
  let municipality_parishes ~municipality ~connection =
    let query =
      Printf.sprintf "SELECT st_astext(st_simplify(geom, %d)) FROM cont_freguesias WHERE municipio = '%s';"
        precision municipality in
    from_query ~connection ~query

  (** Module that defines lower-level polygon serialization functions.*)
  module Xy = struct
    (** Function that returns a polygon as a tuple of arrays of x's and y's.*)
    let get_pol_xy pol =
      let (x, y) = List.fold_left (
        fun (acc_x, acc_y) p' ->
          let x_to_add, y_to_add = List.fold_left (
            fun (x', y') (x_to_add, y_to_add) ->
              (x' @ [x_to_add], y' @ [y_to_add])
          ) ([],[]) p' in
          (acc_x @ x_to_add, acc_y @ y_to_add)
        ) ([], []) pol in
      (Array.of_list x, Array.of_list y)

    (** Function that parses a WKT term as a list of polygons' x and y arrays.*)
    let get_wkt_xy_l pol =
      match pol with
      | Polygon p ->
        [get_pol_xy p]

      | Multipolygon p ->
        List.map (fun p' -> get_pol_xy p') p

    (** Function that serializes a matrix of WKT terms into a list of polygons' x and y arrays.*)
    let get_xy pols_l_l =
      Array.fold_left (fun acc p_l ->
        acc @ (Array.fold_left (
          fun acc' p -> acc' @ get_wkt_xy_l p
        ) [] p_l)
      ) [] pols_l_l

    (** Function that returns the min's and max's of x and y arrays.*)
    let get_min_max_xy (x, y) =
      let min_max a = Array.fold_left (
        fun (mi, ma) a' ->
          (min mi a', max ma a')
      ) (Float.max_float, 0.) a in
      let (min_x, max_x) = min_max x in
      let (min_y, max_y) = min_max y in
      (min_x, max_x, min_y, max_y)

    (** Function that returns the min and max out of all polygons in the map.*)
    let get_min_max l =
      let (min_x, max_x, min_y, max_y) = List.fold_left (
        fun (min_x, max_x, min_y, max_y) xy ->
          let (min_x', max_x', min_y', max_y') = get_min_max_xy xy in
          (min min_x min_x', max max_x max_x', min min_y min_y', max max_y max_y')
      ) (Float.max_float, 0., Float.max_float, 0.) l in
      (min min_x min_y, max max_x max_y)
  end

  (** Function that fills the interior of the map in the plot.*)
  let fill l =
    List.iter (
      fun (x, y) -> plfill x y;
    ) l

  (** Function that outlines the map in the plot.*)
  let outline l =
    List.iter (
      fun (x, y) -> plline x y;
    ) l

  (** Function that draws a polygon (fill and outline) in a plot.*)
  let draw ~polygon ~name ~format ~outline_color ~fill_color () =
    let l = Xy.get_xy polygon in
    let (min_l, max_l) = Xy.get_min_max l in

    plparseopts Sys.argv [PL_PARSE_FULL];

    plsdev format;
    plsfnam name;

    plinit ();

    plenv min_l max_l min_l max_l 0 0;

    plcol0 outline_color;
    fill l;

    plcol0 fill_color;
    outline l;

    plend ();
end
