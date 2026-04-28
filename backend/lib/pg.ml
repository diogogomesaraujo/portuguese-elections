open Postgresql

type wkt_term =
  | Polygon of (float * float) list list
  | Multipolygon of (float * float) list list list
  [@@deriving show]

let wait_for_result c =
  c#consume_input;
  while c#is_busy do
    ignore (Unix.select [ c#socket_descr ] [] [] (-1.0));
    c#consume_input
  done

let fetch_result c =
  wait_for_result c;
  c#get_result

let fetch_single_result c =
  match fetch_result c with
  | None -> assert false
  | Some r ->
      assert (fetch_result c = None);
      r
