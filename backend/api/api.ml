open Backend.Regions
open Backend.Map
open Lwt.Syntax
open Lwt.Infix

module Api = struct
  let headers = [("Access-Control-Allow-Origin", "*")]

  let res = function
    | Ok (Some res) ->
      `String res
      |> Yojson.to_string
      |> Dream.response ~headers
      |> Lwt.return
    | _ -> Yojson.to_string (`List [])
      |> Dream.response ~headers
      |> Lwt.return

  let res_list = function
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

  module Regions = struct
    let regions_req ~name ~arg ~regions =
      Dream.get (Printf.sprintf "/%s/:%s" name arg)
        (fun req -> Dream.sql req (fun conn ->
          let module Conn = (val conn : Caqti_lwt.CONNECTION) in
          let param = Dream.param req arg in
          let%lwt result = Conn.collect_list (regions param) () in
          res_list result)
        )

    let districts =
      regions_req
        ~name: "districts"
        ~arg:  "arg"
        ~regions: Regions.districts

    let municipalities =
      regions_req
        ~name: "municipalities"
        ~arg:  "district"
        ~regions: Regions.municipalities

    let parishes =
      regions_req
        ~name: "parishes"
        ~arg:  "municipality"
        ~regions: Regions.parishes
  end

  module Map = struct
    let map_req ~name ~map ~precision =
      Dream.get (Printf.sprintf "/%s/:%s" name name)
        (fun req -> Dream.sql req (fun conn ->
            let module Conn = (val conn : Caqti_lwt.CONNECTION) in
            let param = Dream.param req name in
            let%lwt result = Conn.find_opt (map param ~precision) () in
            res result
          )
        )

    let country_districts =
      map_req
        ~name: "country"
        ~map: Map.country_districts
        ~precision: 5

    let district_municipalities =
      map_req
        ~name: "district"
        ~map: Map.district_municipalities
        ~precision: 5

    let municipality_parishes =
      map_req
        ~name: "municipality"
        ~map: Map.municipality_parishes
        ~precision: 5

    let parish =
      map_req
        ~name: "parish"
        ~map: Map.parish
        ~precision: 5
  end

  let run =
    Dream.run
    @@ Dream.logger
    @@ Dream.sql_pool "postgresql://localhost:5432/spatial"
    @@ Dream.router [
      Dream.scope "/regions" [Dream.memory_sessions] [
        Regions.districts;
        Regions.municipalities;
        Regions.parishes;
      ];
      Dream.scope "/map" [Dream.memory_sessions] [
        Map.country_districts;
        Map.district_municipalities;
        Map.municipality_parishes;
        Map.parish;
      ]
    ]
end
