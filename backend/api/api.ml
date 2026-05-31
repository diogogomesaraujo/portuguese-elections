open Backend.Elections
open Backend.Regions
open Backend.Table
open Backend.Map
open Lwt.Syntax
open Lwt.Infix

module Api = struct
  let headers = [("Access-Control-Allow-Origin", "*")]

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

    let list_int = function
      | Ok res ->
        let l =
          List.map
            (fun e -> `Int e)
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
  end

  let req ~name ~arg ~regions ~list =
    Dream.get (Printf.sprintf "/%s/:%s" name arg)
      (fun req -> Dream.sql req (fun conn ->
        let module Conn = (val conn : Caqti_lwt.CONNECTION) in
        let param = Dream.param req arg in
        let%lwt result = Conn.collect_list (regions param) () in
        list result)
      )

  module Regions = struct
    let districts =
      req
        ~name: "districts"
        ~arg:  "arg"
        ~regions: Regions.districts
        ~list: Response.list

    let municipalities =
      req
        ~name: "municipalities"
        ~arg:  "district"
        ~regions: Regions.municipalities
        ~list: Response.list

    let parishes =
      req
        ~name: "parishes"
        ~arg:  "municipality"
        ~regions: Regions.parishes
        ~list: Response.list
  end

  module Elections = struct
    let types =
      req
        ~name: "types"
        ~arg:  "arg"
        ~regions: Elections.election_types
        ~list: Response.list

    let years =
      req
        ~name: "years"
        ~arg:  "arg"
        ~regions: Elections.election_years
        ~list: Response.list_int

    let office =
      req
        ~name: "offices"
        ~arg:  "election_type"
        ~regions: Elections.offices
        ~list: Response.list
  end

  module Map = struct
    let req ~name ~map ~precision =
      Dream.get (Printf.sprintf "/%s/:%s" name name)
        (fun req -> Dream.sql req (fun conn ->
            let module Conn = (val conn : Caqti_lwt.CONNECTION) in
            let param = Dream.param req name in
            let%lwt result = Conn.find_opt (map param ~precision) () in
            Response.one result
          )
        )

    let country_districts =
      req
        ~name: "country"
        ~map: Map.country_districts
        ~precision: 50

    let district_municipalities =
      req
        ~name: "district"
        ~map: Map.district_municipalities
        ~precision: 1

    let municipality_parishes =
      req
        ~name: "municipality"
        ~map: Map.municipality_parishes
        ~precision: 1

    let parish =
      req
        ~name: "parish"
        ~map: Map.parish
        ~precision: 1
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
        Map.country_districts;
        Map.district_municipalities;
        Map.municipality_parishes;
        Map.parish;
      ];
      Dream.scope "/table" [Dream.memory_sessions] [
        Table.generic;
      ]
    ]
end
