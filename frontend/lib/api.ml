open Core
open Async_kernel
open Async_js

module Api = struct
  let get ?arguments ~uri () =
    Deferred.Result.map
      ~f: (fun res -> res)
      (Http.get ?arguments uri)
end
