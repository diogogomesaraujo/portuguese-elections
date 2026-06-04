open Backend.Territory
open Backend.Elections
open Backend.Regions
open Backend.Table
open Backend.Req
open Backend.Map
open Lwt.Syntax
open Lwt.Infix

module Api = struct
  let headers = [("Access-Control-Allow-Origin", "*");
    ("Content-Type", "application/json; charset=utf-8")]

  let microservice_uri = "http://localhost:8000"

  module Response = struct
    let one = function
      | Ok (Some res) ->
        `String res
        |> Yojson.to_string
        |> Dream.response ~headers
        |> Lwt.return
      | _ -> Yojson.to_string (`List [])
        |> Dream.response ~headers
        |> Lwt.return

    let two = function
      | Ok(r1, r2) ->
        `Tuple [`String r1; `Int r2]
        |> Yojson.to_string
        |> Dream.response ~headers
        |> Lwt.return
      | _ -> Yojson.to_string (`Tuple [])
        |> Dream.response ~headers
        |> Lwt.return

    let list = function
      | Ok res ->
        let l =
          List.map
            (fun e -> `String e)
            res
        in
        `List l
        |> Yojson.to_string
        |> Dream.response ~headers
        |> Lwt.return
      | Error e -> Yojson.to_string (`List [])
        |> Dream.response ~headers
        |> Lwt.return

    let list_t4 ~header = function
      | Ok res ->
        let (l1, l2, l3, l4) =
          List.fold_left
            (fun (acc1, acc2, acc3, acc4) (e1, e2, e3, e4) ->
              ( acc1 @ [`String e1]
              , acc2 @ [`String e2]
              , acc3 @ [`String e3]
              , acc4 @ [`String e4]))
            ([], [], [], [])
            res
        in
        let header = List.map (
          fun h -> `String h
        ) header in
        `List [`List header; `List l1; `List l2; `List l3; `List l4]
        |> Yojson.to_string
        |> Dream.response ~headers
        |> Lwt.return
      | Error e -> Yojson.to_string (`List [])
        |> Dream.response ~headers
        |> Lwt.return

    let list_t2 = function
      | Ok res ->
        let (l1, l2) =
          List.fold_left
            (fun (acc1, acc2) (e1, e2) ->
              ( acc1 @ [`String e1]
              , acc2 @ [`String e2]))
            ([], [])
            res
        in
        `List [`List l1; `List l2]
        |> Yojson.to_string
        |> Dream.response ~headers
        |> Lwt.return
      | Error e -> Yojson.to_string (`List [])
        |> Dream.response ~headers
        |> Lwt.return
  end

  module Regions = struct
    let req ~name ~arg ~regions =
      Dream.get (Printf.sprintf "/%s/:%s" name arg)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in
          let param = Dream.param req arg in
          let%lwt result = Conn.collect_list (regions param) () in
          Response.list result)
        )

    let districts =
      req
        ~name: "districts"
        ~arg:  "arg"
        ~regions: Regions.districts

    let municipalities =
      req
        ~name: "municipalities"
        ~arg:  "district"
        ~regions: Regions.municipalities

    let parishes =
      req
        ~name: "parishes"
        ~arg:  "municipality"
        ~regions: Regions.parishes
  end

  module Elections = struct
    let req ~name ~arg ~regions ~list =
      Dream.get (Printf.sprintf "/%s/:%s" name arg)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in
          let param = Dream.param req arg in
          let%lwt result = Conn.collect_list (regions param) () in
          list result)
        )

    let req_2 ~name ~arg ~regions =
      Dream.get (Printf.sprintf "/%s/:%s" name arg)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in
          let typ = Dream.param req arg in
          let%lwt res = Conn.collect_list (regions typ) () in
          Response.list_t2 res)
        )

    let types =
      req
        ~name: "types"
        ~arg:  "arg"
        ~regions: Elections.election_types
        ~list: Response.list

    let years =
      req
        ~name: "years"
        ~arg:  "election_type"
        ~regions: Elections.election_years
        ~list: Response.list

    let office =
      req_2
        ~name: "offices"
        ~arg:  "election_type"
        ~regions: Elections.offices

  end

  module Map = struct
    let get =
      Dream.get "/:key/:type/:year/:office"
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let key           = Dream.param req "key"   |> Uri.pct_decode in
          let election_type = Dream.param req "type"   |> Uri.pct_decode in
          let election_year = Dream.param req "year"   |> Uri.pct_decode in
          let office        = Dream.param req "office" |> Uri.pct_decode in

          let%lwt result = Conn.find_opt (Map.get
                                            ~key
                                            ~precision: 1
                                            ~election_type
                                            ~election_year
                                            ~office) ()
          in Response.one result))
  end

  module Table = struct
    let req_4 ~name ~(table: 'a * ( unit, string * string * string * string, [< `Many | `One | `Zero ] ) Caqti_request.t) =
      let header, data = table in
      Dream.get (Printf.sprintf "/%s" name)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in
          let%lwt res = Conn.collect_list data () in
          Response.list_t4 ~header res)
        )

    let generic =
      req_4
        ~name: "generic"
        ~table: Table.generic
  end

  module Plot = struct
    let req ~name ~microservice_uri =
      Dream.get (Printf.sprintf "/%s/:type/:year/:office/:key" name)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let election_type = Dream.param req "type"    |> Uri.pct_decode in
          let election_year = Dream.param req "year"    |> Uri.pct_decode in
          let office        = Dream.param req "office"  |> Uri.pct_decode in
          let key           = Dream.param req "key"     |> Uri.pct_decode in

          let uri =
            Printf.sprintf "%s/%s/%s/%s/%s/%s"
              microservice_uri name
              (Req.to_param (election_type, false))
              (Req.to_param (election_year, false))
              (Req.to_param (office, false))
              (Req.to_param (key, false))
          in

          let%lwt res = Req.get ~uri in

          `String res
          |> Yojson.to_string
          |> Dream.response ~headers
          |> Lwt.return
          ))

    let req_rise_and_fall ~name ~microservice_uri =
      Dream.get (Printf.sprintf "/%s/:type/:office/:key/:metric/:direction" name)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let election_type = Dream.param req "type"      |> Uri.pct_decode in
          let office        = Dream.param req "office"    |> Uri.pct_decode in
          let key           = Dream.param req "key"       |> Uri.pct_decode in
          let metric        = Dream.param req "metric"    |> Uri.pct_decode in
          let direction     = Dream.param req "direction" |> Uri.pct_decode in

          let uri =
            Printf.sprintf "%s/%s/%s/%s/%s/%s/%s"
              microservice_uri name
              (Req.to_param (election_type, false))
              (Req.to_param (office, false))
              (Req.to_param (key, false))
              (Req.to_param (metric, false))
              (Req.to_param (direction, false))
          in

          let%lwt res = Req.get ~uri in

          `String res
          |> Yojson.to_string
          |> Dream.response ~headers
          |> Lwt.return
          ))

    let req_swingmap ~name ~microservice_uri =
      Dream.get (Printf.sprintf "/%s/:type/:office/:key" name)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let election_type = Dream.param req "type"    |> Uri.pct_decode in
          let office        = Dream.param req "office"  |> Uri.pct_decode in
          let key           = Dream.param req "key"     |> Uri.pct_decode in

          let uri =
            Printf.sprintf "%s/%s/%s/%s/%s"
              microservice_uri name
              (Req.to_param (election_type, false))
              (Req.to_param (office, false))
              (Req.to_param (key, false))
          in

          let%lwt res = Req.get ~uri in

          `String res
          |> Yojson.to_string
          |> Dream.response ~headers
          |> Lwt.return
          ))


    let treemap =
      req
        ~name: "treemap"
        ~microservice_uri

    let rise_and_fall =
      req_rise_and_fall
        ~name: "riseandfall"
        ~microservice_uri

    let distribution =
      req
        ~name: "distribution"
        ~microservice_uri

    let abstention =
      req
        ~name: "abstention"
        ~microservice_uri

    let swingmap =
      req_swingmap
        ~name: "swingmap"
        ~microservice_uri
  end

  module Territory = struct
    let get =
      Dream.get "/:district/:municipality/:parish"
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let district     = Dream.param req "district"     |> Uri.pct_decode in
          let municipality = Dream.param req "municipality" |> Uri.pct_decode in
          let parish       = Dream.param req "parish"       |> Uri.pct_decode in

          let%lwt res = Conn.find_opt (Territory.key ~district ~municipality ~parish) () in
          res |> Response.one))

    let name =
      Dream.get "/name/:key"
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in

          let key     = Dream.param req "key" |> Uri.pct_decode in

          let%lwt res = Conn.find_opt (Territory.name ~key) () in
          res |> Response.one))
  end

  let run =
    Dream.run
    @@ Dream.logger
    @@ Dream.sql_pool "postgresql://localhost:5432/elections"
    @@ Dream.router [
      Dream.scope "/regions" [Dream.memory_sessions] [
        Regions.districts;
        Regions.municipalities;
        Regions.parishes;
      ];
      Dream.scope "/election" [Dream.memory_sessions] [
        Elections.office;
        Elections.types;
        Elections.years;
      ];
      Dream.scope "/map" [Dream.memory_sessions] [
        Map.get;
      ];
      Dream.scope "/table" [Dream.memory_sessions] [
        Table.generic;
      ];
      Dream.scope "/plot" [Dream.memory_sessions] [
        Plot.treemap;
        Plot.rise_and_fall;
        Plot.distribution;
        Plot.abstention;
        Plot.swingmap;
      ];
      Dream.scope "/territory" [Dream.memory_sessions] [
        Territory.get;
        Territory.name;
      ]
    ]
end
