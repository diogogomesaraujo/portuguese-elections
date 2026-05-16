open Backend.Map
open Lwt.Syntax
open Lwt.Infix

module Api = struct

  let country_districts ~connection =
    let module Conn = (val connection : Caqti_lwt.CONNECTION) in
    Dream.get "/country"
      (fun _ ->
        let%lwt result = Conn.collect_list (Map.country_districts ~precision: 1) () in
        match result with
        | Ok res ->
          let tuple_lst =
            List.map (fun (district, svg) ->
              `Tuple [`String district; `String svg])
            res in
          Yojson.to_string (`List tuple_lst)
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
        | Error e -> Yojson.to_string (`List [])
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
      )

  let district_municipalities ~connection =
    let module Conn = (val connection : Caqti_lwt.CONNECTION) in
    Dream.get "/district/:district"
      (fun req ->
        let district = Dream.param req "district" in
        let%lwt result = Conn.collect_list (Map.district_municipalities ~district ~precision: 1) () in
        match result with
        | Ok res ->
          let tuple_lst =
            List.map (fun (municipality, svg) ->
              `Tuple [`String municipality; `String svg])
            res in
          Yojson.to_string (`List tuple_lst)
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
        | Error e -> Yojson.to_string (`List [])
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
      )

  let municipality_parishes ~connection =
    let module Conn = (val connection : Caqti_lwt.CONNECTION) in
    Dream.get "/municipality/:municipality"
      (fun req ->
        let municipality = Dream.param req "municipality" in
        let%lwt result = Conn.collect_list (Map.municipality_parishes ~municipality ~precision: 1) () in
        match result with
        | Ok res ->
          let tuple_lst =
            List.map (fun (parish, svg) ->
              `Tuple [`String parish; `String svg])
            res in
          Yojson.to_string (`List tuple_lst)
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
        | Error e -> Yojson.to_string (`List [])
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
      )

  let parish ~connection =
    let module Conn = (val connection : Caqti_lwt.CONNECTION) in
    Dream.get "/parish/:parish"
      (fun req ->
        let parish = Dream.param req "parish" in
        let%lwt result = Conn.find_opt (Map.parish ~parish ~precision: 1) () in
        match result with
        | Ok res ->
          `String (Option.get res)
          |> Yojson.to_string
          |> Dream.response ~headers: [("Access-Control-Allow-Origin", "*")]
          |> Lwt.return
        | Error e -> Yojson.to_string (`List [])
          |> Dream.response
          |> Lwt.return
      )

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
