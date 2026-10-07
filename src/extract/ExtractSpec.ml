(** Dispatcher from the generic {!Spec} IR to the concrete spec printer.

    Currently, guarded by a config flag to be only for the Lean backend. *)

module F = Format

(** Emit one [Spec.spec] entry. *)
let emit_spec ctx fmt (s : Spec.spec) =
  match s.kind with
  | HaxSpec hs -> ExtractHaxSpecs.emit_spec ctx fmt hs s.span

(** Emit one [Spec.proof_obligation] entry. *)
let emit_proof_obligation ctx fmt (o : Spec.proof_obligation) =
  match o.kind with
  | HaxProof ho -> ExtractHaxSpecs.emit_obligation ctx fmt ho o.span

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
            | HaxSpec hs -> ExtractHaxSpecs.register_spec_names ctx s.id hs)
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

let extract_specs ctx fmt = List.iter (emit_spec ctx fmt) ctx.specs

let extract_proof_obligations ctx fmt =
  List.iter (emit_proof_obligation ctx fmt) ctx.proof_obligations
