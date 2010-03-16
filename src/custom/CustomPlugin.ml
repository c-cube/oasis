
(** Generate custom configure/build/doc/test/install system
    @author
  *)

open BaseEnv
open OASISTypes

TYPE_CONV_PATH "CustomPlugin"

type t =
    {
      cmd_main:      command_line conditional;
      cmd_clean:     (command_line option) conditional;
      cmd_distclean: (command_line option) conditional;
    } with odn

let run cmd args extra_args =
  BaseExec.run 
    (var_expand cmd)
    (List.map 
       var_expand
       (args @ (Array.to_list extra_args)))

let main t _ extra_args =
  let cmd, args =
    var_choose t.cmd_main
  in
    run cmd args extra_args 

let clean t pkg extra_args =
  match var_choose t.cmd_clean with
    | Some (cmd, args) ->
        run cmd args extra_args
    | _ ->
        ()

let distclean t pkg extra_args =
  match var_choose t.cmd_distclean with
    | Some (cmd, args) ->
        run cmd args extra_args
    | _ ->
        ()

module Test =
struct
  let main t pkg (cs, test) extra_args =
    try
      main t pkg extra_args;
      0.0
    with Failure _ ->
      1.0

  let clean t pkg (cs, test) extra_args =
    clean t pkg extra_args

  let distclean t pkg (cs, test) extra_args =
    distclean t pkg extra_args 
end

module Doc =
struct
  let main t pkg (cs, ()) extra_args =
    main t pkg extra_args

  let clean t pkg (cs, ()) extra_args =
    clean t pkg extra_args

  let distclean t pkg (cs, ()) extra_args =
    distclean t pkg extra_args
end

(* END EXPORT *)

open OASISGettext
open ODN
open OASISTypes
open OASISValues

module Id =
struct
  let name    = "Custom"
  let version = OASISConf.version
end

module Make (PU: OASISPlugin.PLUGIN_UTILS_TYPE) =
struct
  (** Add standard fields 
    *)
  let add_fields
        ?(schema=OASISPackage.schema)
        nm 
        hlp 
        hlp_clean 
        hlp_distclean =
    let cmd_main =
      PU.new_field_conditional
        schema
        nm
        command_line
        hlp
    in
    let cmd_clean =
      PU.new_field_conditional
        schema
        (nm^"Clean")
        ~default:None
        (opt command_line)
        hlp_clean
    in
    let cmd_distclean =
      PU.new_field_conditional
        schema
        (nm^"Distclean")
        ~default:None
        (opt command_line)
        hlp_distclean
    in
      cmd_main, cmd_clean, cmd_distclean

  (** Standard custom handling
    *)
  let std nm hlp hlp_clean hlp_distclean =
    let cmd_main, cmd_clean, cmd_distclean =
      add_fields nm hlp hlp_clean hlp_distclean 
    in
      fun pkg -> 
        let t =
          {
            cmd_main      = cmd_main pkg.schema_data;
            cmd_clean     = cmd_clean pkg.schema_data;
            cmd_distclean = cmd_distclean pkg.schema_data;
          }
        in
          {
            OASISPlugin.moduls = 
              [CustomData.customsys_ml];

            setup = 
              ODNFunc.func_with_arg 
                main ("CustomPlugin.main")
                t odn_of_t;

            clean = 
              Some 
                (ODNFunc.func_with_arg
                   clean ("CustomPlugin.clean")
                   t odn_of_t);

            distclean = 
              Some 
                (ODNFunc.func_with_arg
                   distclean ("CustomPlugin.distclean")
                   t odn_of_t);

            other_action = 
              ignore;
          },
          pkg
end

(* Configure plugin *)
let () = 
  let module PU = OASISPlugin.Configure.Make(Id)
  in
  let module CU = Make(PU)
  in
  let doit =
    CU.std
      "Conf"
      (fun () -> s_ "Run command to configure.")
      (fun () -> s_ "Run command to clean configure step.")
      (fun () -> s_ "Run command to distclean configure step.")
  in
    PU.register doit

(* Build plugin *)
let () = 
  let module PU = OASISPlugin.Build.Make(Id)
  in
  let module CU = Make(PU)
  in
  let doit = 
    CU.std
      "Build"
      (fun () -> s_ "Run command to build.")
      (fun () -> s_ "Run command to clean build step.")
      (fun () -> s_ "Run command to distclean build step.")
  in
    PU.register doit

(* Install plugin *)
let () =
  let module PU = OASISPlugin.Install.Make(Id)
  in
  let module CU = Make(PU)
  in
  let doit_install = 
    CU.std
      "Install"
      (fun () -> s_ "Run command to install.")
      (fun () -> s_ "Run command to clean install step.")
      (fun () -> s_ "Run command to distclean install step.")
  in
  let doit_uninstall = 
    CU.std
      "Uninstall"
      (fun () -> s_ "Run command to uninstall.")
      (fun () -> s_ "Run command to clean uninstall step.")
      (fun () -> s_ "Run command to distclean uninstall step.")
  in
    PU.register (doit_install, doit_uninstall)

(* Documentation plugin *)
let doc =
  let module PU = OASISPlugin.Doc.Make(Id)
  in
  let module CU = Make(PU)
  in
  let cmd_main, cmd_clean, cmd_distclean =
    CU.add_fields
      (* TODO: use document *)
      ~schema:OASISPackage.schema
      "Doc"
      (fun () -> s_ "Run command to build documentation.")
      (fun () -> s_ "Run command to clean build documentation step.")
      (fun () -> s_ "Run command to distclean build documentation step.")
  in
  let doit pkg (cs, doc) =
      let t =
        {
          cmd_main      = cmd_main pkg.schema_data;
          cmd_clean     = cmd_clean pkg.schema_data;
          cmd_distclean = cmd_distclean pkg.schema_data;
        }
      in
        {
          OASISPlugin.moduls = 
            [CustomData.customsys_ml];

          setup = 
            ODNFunc.func_with_arg 
              Doc.main ("CustomPlugin.Doc.main")
              t odn_of_t;

          clean = 
            Some 
              (ODNFunc.func_with_arg
                 Doc.clean ("CustomPlugin.Doc.clean")
                 t odn_of_t);

          distclean = 
            Some 
              (ODNFunc.func_with_arg
                 Doc.distclean ("CustomPlugin.Doc.distclean")
                 t odn_of_t);

          other_action = 
            ignore;
        },
        pkg,
        cs,
        doc
  in
    PU.register doit

(* Test plugin *)
let () =
  let module PU = OASISPlugin.Test.Make(Id)
  in
  let module CU = Make(PU)
  in
  let test_clean =
    PU.new_field_conditional
      OASISTest.schema
      "Clean"
      ~default:None
      (opt command_line)
      (fun () ->
         s_ "Run command to clean test step.")
  in
  let test_distclean =
    PU.new_field_conditional
      OASISTest.schema
      "Distclean"
      ~default:None
      (opt command_line)
      (fun () ->
         s_ "Run command to distclean test step.")
  in
  let doit pkg (cs, test) =
      let t = 
        { 
          cmd_main      = test.test_command;
          cmd_clean     = test_clean cs.cs_data;
          cmd_distclean = test_distclean cs.cs_data;
        }
      in
        {
          OASISPlugin.moduls = 
            [CustomData.customsys_ml];

          setup = 
            ODNFunc.func_with_arg 
              Test.main ("CustomPlugin.Test.main")
              t odn_of_t;

          clean = 
            Some 
              (ODNFunc.func_with_arg
                 Test.clean ("CustomPlugin.Test.clean")
                 t odn_of_t);

          distclean = 
            Some 
              (ODNFunc.func_with_arg
                 Test.distclean ("CustomPlugin.Test.distclean")
                 t odn_of_t);

          other_action = 
            ignore;
        },
        pkg,
        cs,
        test
  in
    PU.register doit