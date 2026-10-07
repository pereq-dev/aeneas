(** Lean printer for {!HaxSpecs.spec} and {!HaxSpecs.obligation} entries. *)

module F = Format

(** Registers the names generated for a spec (after the crate items); also
    returns whether one of them clashes with a name registered before *)
val register_spec_names :
  ExtractBase.extraction_ctx ->
  Spec.SpecId.id ->
  HaxSpecs.spec ->
  ExtractBase.extraction_ctx * bool

(** Registers the name of a proof obligation (after the crate items); also
    returns whether it clashes with a name registered before *)
val register_obligation_names :
  ExtractBase.extraction_ctx ->
  Spec.ProofId.id ->
  HaxSpecs.obligation ->
  ExtractBase.extraction_ctx * bool

(** Emits one [HaxSpecs.spec] entry. The [span option] is used for errors *)
val emit_spec :
  ExtractBase.extraction_ctx ->
  F.formatter ->
  HaxSpecs.spec ->
  Meta.span option ->
  unit

(** Emits one [HaxSpecs.obligation] entry. The [span option] is used for errors
*)
val emit_obligation :
  ExtractBase.extraction_ctx ->
  F.formatter ->
  HaxSpecs.obligation ->
  Meta.span option ->
  unit
