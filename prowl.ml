open Core.Std
open Async.Std
open Cohttp_async

let api_key =
  match Core.Std.Sys.getenv "PROWL_API_KEY" with
  | Some key -> key
  | None -> failwith "API key not found; try setting $PROWL_API_KEY "
;;

let api_url = "http://api.prowlapp.com/publicapi/"

type t =
  { priority : int option  (* [-2, 2] *)
  ; url : string option    (* 512 *)
  ; application : string   (* 256 *)
  ; event : string         (* 1024 *)
  ; description : string } (* 10000 *)
with fields


let fields_flag spec ~doc ?aliases s field =
  let open Command.Spec in
  let name = Fieldslib.Field.name field in
  let name = String.tr ~target:'_' ~replacement:'-' name in
  s +> flag ("-" ^ name) spec ~doc ?aliases
;;


let uri_of_t api_key api_method t =
  let uri = Uri.of_string (api_url ^ api_method) in
  let add_p to_s = fun acc f ->
    Uri.add_query_param acc
      (Field.name f, [to_s (Field.get f t)])
  in
  Fields.fold
    ~init:(Uri.add_query_param uri ("apikey", [api_key]))
    ~priority:(add_p
                 (function
                 | None -> "0"
                 | Some i when i > 2 -> "2"
                 | Some i when i < -2 -> "-2"
                 | Some i -> Int.to_string i))
    ~url:(add_p
            (function
            | None -> ""
            | Some u -> u))
    ~application:(add_p Fn.id)
    ~event:(add_p Fn.id)
    ~description:(add_p Fn.id)
;;

let send uri =
  let host = Option.value_exn (Uri.host uri) in
  match Uri_services.tcp_port_of_uri uri with
  | None -> failwith "could not determine port from URI"
  | Some port ->
    Tcp.with_connection (Tcp.to_host_and_port host port)
      (fun _ ic oc ->
        Client.call `POST uri
        >>= function
        | None -> failwith "request failed"
        | Some (res, body) ->
          let status = Response.status res in
          begin
            match Cohttp.Code.code_of_status status with
            | 200 -> printf "Success\n%!"
            | _   -> failwithf "Request failed with status %s\n%!"
              (Cohttp.Code.string_of_status status) ()
          end;
          return ())
;;

module Add = struct
  let go api_key t =
    let uri = uri_of_t api_key "add" t in
    send uri
  ;;

  let command =
    Command.async_basic ~summary:"send a notification"
      Command.Spec.(
        Fields.fold
          ~init:(step Fn.id)
          ~priority:(fields_flag
                       (optional int)
                       ~doc:"priority (integer between -2 and 2)"
                       ~aliases:["-p"])
          ~url:(fields_flag
                  (optional string)
                  ~doc:"url which should be attached to the notification"
                  ~aliases:["-u"])
          ~application:(fields_flag
                          (required string)
                          ~doc:"name of the application generating the event"
                  ~aliases:["-a"])
          ~event:(fields_flag
                    (required string)
                    ~doc:"name of the event or subject of the notification"
                    ~aliases:["-e"])
          ~description:(fields_flag
                          (required string)
                          ~doc:"description of the event"
                          ~aliases:["-d"]))
      (fun priority url application event description () ->
        go api_key {priority; url; application; event; description})
end

let command =
  Command.group ~summary:"interact with the Prowl API"
    [("add", Add.command)]
;;

let () = Exn.handle_uncaught ~exit:true (fun () -> Command.run command)
