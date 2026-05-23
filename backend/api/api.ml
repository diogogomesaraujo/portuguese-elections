open Backend.Map
open Lwt.Syntax
open Lwt.Infix

module Api = struct
  let headers = [("Access-Control-Allow-Origin", "*")]

  let res = function
    | Ok res ->
      `String (Option.get res)
      |> Yojson.to_string
      |> Dream.response ~headers
      |> Lwt.return
    | Error e -> Yojson.to_string (`List [])
      |> Dream.response
      |> Lwt.return

  let map_req ~connection ~name ~map ~precision =
    let module Conn = (val connection : Caqti_lwt.CONNECTION) in
    Dream.get (Printf.sprintf "/%s/:%s" name name)
      (fun req ->
        let param = Dream.param req name in
        let%lwt result = Conn.find_opt (map param ~precision) () in
        res result
      )

  let country_districts ~connection =
    map_req
      ~connection
      ~name: "country"
      ~map: Map.country_districts
      ~precision: 5

  let district_municipalities ~connection =
    map_req
      ~connection
      ~name: "district"
      ~map: Map.district_municipalities
      ~precision: 5

  let municipality_parishes ~connection =
    map_req
      ~connection
      ~name: "municipality"
      ~map: Map.municipality_parishes
      ~precision: 5

  let parish ~connection =
    map_req
      ~connection
      ~name: "parish"
      ~map: Map.parish
      ~precision: 5

  let run ~connection =
    Dream.run
    @@ Dream.logger
    @@ Dream.router [
      Dream.scope "/map" [Dream.memory_sessions] [
        country_districts       ~connection;
        district_municipalities ~connection;
        municipality_parishes   ~connection;
        parish                  ~connection;
      ]
    ]
end
