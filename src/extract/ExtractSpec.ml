(** Dispatcher from the generic {!Spec} IR to the concrete spec printer.

    Currently, guarded by a config flag to be only for the Lean backend. *)

module F = Format

(** Emit one [Spec.spec] entry. *)
let emit_spec ctx fmt (s : Spec.spec) =
  match s.kind with
  | HaxSpec hs -> ExtractHaxSpecs.emit_spec ctx fmt hs

(** Emit one [Spec.proof_obligation] entry. *)
let emit_proof_obligation ctx fmt (o : Spec.proof_obligation) =
  match o.kind with
  | HaxProof ho -> ExtractHaxSpecs.emit_obligation ctx fmt ho

(** Raised by {!register_names} when a generated name clashes with a name
    registered before: the clashes were already reported. *)
exception Name_clash

(** Register the names generated for the specs and proof obligations. Must be
    called after registering the crate items, and before writing any file.

    A clash is fatal, even without [-abort-on-error]: Lean would reject the
    duplicate definitions. We register all the names (to report all the
    clashes), then raise {!Name_clash} if there was one. Other errors are
    reported and the extraction goes on, as for the crate items. *)
let register_names (ctx : ExtractBase.extraction_ctx) :
    ExtractBase.extraction_ctx =
  let register (what : string)
      (f : ExtractBase.extraction_ctx -> ExtractBase.extraction_ctx * bool)
      ((ctx, clash) : ExtractBase.extraction_ctx * bool) =
    try
      let ctx, clash' = f ctx in
      (ctx, clash || clash')
    with Errors.CFailure error ->
      (* An exception was raised (the error was already registered): ignore
         it *)
      [%warn_opt_span] error.span
        ("Could not generate names for the " ^ what
       ^ " because of previous error");
      (ctx, clash)
  in
  let acc =
    List.fold_left
      (fun acc (s : Spec.spec) ->
        register "spec"
          (fun ctx ->
            match s.kind with
            | HaxSpec hs ->
                ExtractHaxSpecs.register_spec_names ctx s.id hs s.span)
          acc)
      (ctx, false) ctx.specs
  in
  let ctx, clash =
    List.fold_left
      (fun acc (o : Spec.proof_obligation) ->
        register "proof obligation"
          (fun ctx ->
            match o.kind with
            | HaxProof ho ->
                ExtractHaxSpecs.register_obligation_names ctx o.id ho)
          acc)
      acc ctx.proof_obligations
  in
  if clash then raise Name_clash;
  ctx

(** Print the entry [x] with [emit], ignoring a [CFailure]: it was normally
    reported when raised, and only drops [x]. The entry is printed in a buffer
    first, so that a partial output (with unclosed boxes) is dropped too. [fmt]
    must be in a vertical box at column 0, as the entries are. *)
let skip_on_failure fmt (emit : F.formatter -> 'a -> unit) (x : 'a) : unit =
  let buf = Buffer.create 1024 in
  let bfmt = F.formatter_of_buffer buf in
  FormatCompat.use_byte_width bfmt;
  let { F.margin; max_indent } = F.pp_get_geometry fmt () in
  F.pp_set_geometry bfmt ~max_indent ~margin;
  F.pp_open_vbox bfmt 0;
  match emit bfmt x with
  | () ->
      F.pp_close_box bfmt ();
      F.pp_print_flush bfmt ();
      List.iteri
        (fun i line ->
          if i > 0 then F.pp_print_cut fmt ();
          F.pp_print_string fmt line)
        (String.split_on_char '\n' (Buffer.contents buf))
  | exception Errors.CFailure _ -> ()

let extract_specs ctx fmt =
  List.iter (skip_on_failure fmt (emit_spec ctx)) ctx.specs

let extract_proof_obligations ctx fmt =
  List.iter
    (skip_on_failure fmt (emit_proof_obligation ctx))
    ctx.proof_obligations
