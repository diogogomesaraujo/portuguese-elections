open Backend.Map
open Svg

module Api = struct
  let map ~connection ~config ~polygon ~path =
    Map.draw ~polygon ~config ~path();
    svg_from_file ~path
      ~headers: [("Access-Control-Allow-Origin", "*")]
    |> Lwt.return

  let country_parishes ~connection ~config =
    let path = "assets/portugal.svg" in
    let precision = 1000 in
    let polygon = Map.country_parishes ~connection ~precision in
    Dream.get "/country_parishes" (fun _ -> map ~connection ~config ~polygon ~path)

  let district_parishes ~connection ~config =
    let precision = 50 in
    Dream.get "/district/:district"
      (fun req ->
        let district = Dream.param req "district" in
        let polygon = Map.district_parishes ~district ~connection ~precision in
        let path = Printf.sprintf "assets/%s.svg" district in
        map ~connection ~config ~polygon ~path
      )

  let run ~connection ~config () =
    Dream.run
    @@ Dream.logger
    @@ Dream.router [
      Dream.scope "/map" [Dream.memory_sessions] [
        country_parishes  ~connection ~config;
        district_parishes ~connection ~config;
      ]
    ]
end
