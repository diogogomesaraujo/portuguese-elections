open Pg
open Parse

module Map = struct
  let connect = new Postgresql.connection ~conninfo:"host=localhost port=5432 dbname=spatial user=diogoaraujo" ()

  let get_polygon (c: Postgresql.connection) query =
    c#send_query query;
    Array.map (fun r -> Array.map (
      fun c ->
      parse c
    ) r) (fetch_single_result c)#get_all
end
