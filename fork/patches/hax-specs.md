# hax-specs

## Summary

With `-specs hax`, `hax_lib::requires`/`ensures` annotations become Lean specs
and proof obligations (fork PRs #7, #58, #62). For `f` with a precondition and a
postcondition, Aeneas emits `f.pre`, `f.post`, `f.spec` and an obligation
`f.spec.proof`. The design is generic: `src/specs/Spec.ml` is the spec
interface, `src/specs/HaxProducer.ml` gathers hax specs (helpers in
`src/utils/HaxAttributes.ml`), `src/extract/ExtractSpec.ml` dispatches the
printing and `src/extract/ExtractHaxSpecs.ml` prints hax specs. `f.spec` is an
`mvcgen`-style Hoare triple (files that use specs `open Std.Do`); the
`step`-style backend (`-specs hax-step`) was removed (fork PR #76).

A prepass (`HaxLateSkipFilterPrePass`) removes the items hax marks as
`late_skip` (helper items without a `Uid`); decoration functions (with a `Uid`)
are consumed by the producer.

## Invariants

- Without `-specs`, the output is unchanged and the prepass is a no-op.
- Decoration functions never appear as such; only as `<fn>.pre`/`<fn>.post`.
- Arguments of spec functions are printed with `Extract.extract_App` (#58).
- Specs and obligations pass every input of the function, in order: unit
  inputs, which are extracted as `_` binders, are passed as `()` (#79).
- The trait clauses of the conditions of a trait method differ from the
  method's: the clauses of the method's own generics come first, and the
  where-clauses of the trait are separate clauses. Each clause of a condition
  is instantiated with the matching trait ref of the method or one of its
  transitive parent clauses (`cond_generics`, #80): hax-lib (up to 0.5.0) adds
  the supertraits of the trait as bounds of the conditions. Not supported: a
  supertrait with associated types, which Charon turns into type parameters of
  the conditions that the method does not have (an error).
- Conditions on a required trait method (no default body) are dropped,
  without a warning: no `pre`/`post`/spec/obligation is extracted for them.
- The names `<fn>.pre`, `<fn>.post`, `<fn>.spec` and `<fn>.spec.proof` derive
  from the registered name of `<fn>` (the conditions of a default method
  `<Trait>.<m>.default` are `<Trait>.<m>.pre`/`.post`). They are registered
  (`ExtractSpec.register_names`: the conditions under their function ids, the
  spec and the obligation under `SpecId`/`ProofObligationId`) after the crate
  items, so a clash with an item of the crate, or between the names generated
  for two functions with the same registered name, is an error (#82). Such a
  clash is fatal even without `-abort-on-error`: all the clashes are
  reported, then the extraction stops before writing any file
  (`ExtractSpec.Name_clash`), since Lean would reject the duplicate
  definitions.
- Obligations are plain theorems, not `@[spec]` lemmas: users register the
  specs they prove.
- Spec and obligation files are emitted only when non-empty; their imports come
  from `Spec.required_imports`.
- With the default `-use-lean-modules`, the hax proof library (`Hax`) must be a
  Lean module: generated files are modules and `public import Hax`.

## Tests

- `tests/hax` (fork PR #83) is a crate on `hax-lib` 0.5, extracted the way
  hax users do it: `cargo hax extract` runs the proof scenario `hax-tests` of
  `tests/hax/hax.toml`, which points hax at `bin/aeneas` and
  `charon/bin/charon`. The extracted code (`tests/hax/proofs/hax-tests/lean`,
  Lean package `HaxTests`, under `Extraction/`) is committed, next to
  handwritten assumptions (`Assumptions/`) and proofs of the obligations
  (`Verification/`). Every contract is proved; one that cannot be is left out
  of the crate, with a comment. `make verify-hax` checks that every obligation
  has a proof, not commented out and without `sorry`.
- The modules of `tests/hax/src/specs/`: the shape of contracts, arguments
  (unit arguments, #79), `&mut` inputs and `future`, generics, mutually
  recursive functions, trait methods (`specs/traits/condition_clauses.rs`:
  trait clauses of conditions and supertraits, direct and transitive, #80,
  and the dropped conditions of the required method `D::required`; the
  trait-level testsuite of `specs/traits/`) and names that look like generated
  ones without clashing (#82).
- `tests/hax/failures/clash_pre` and `tests/hax/failures/clash_spec`: an item
  `foo::pre` (resp. `foo::spec`) clashes with the precondition (resp. the
  spec) of a contracted `foo`, which is an error (#82). One crate per clash,
  so that each output shows one. `make extract-hax` extracts each
  crate of `tests/hax/failures` with `cargo hax extract`, expects it to fail,
  and records the error of Aeneas in `tests/hax/failures/<crate>.out`
  (committed).
- `tests/hax/failures/supertrait_assoc`: conditions of a method of a trait
  whose supertrait has an associated type, which is an error (#80).
- Not run by `make test`: `make test-hax` (`scripts/test-hax.sh`; `extract-hax`
  and `verify-hax` run the two steps). By default it uses the release of hax
  that the crates require: the `hax-lib` they resolve to, the `cargo-hax` of
  the same version (installed in `tests/hax/.hax-cache`) and the hax Lean
  library of the `hax-lib` package; `HAX_DIR=<hax checkout>` uses a checkout
  and the `cargo hax` on PATH instead. `make clean-generated-aeneas` leaves
  `tests/hax` alone.
- The CI job `hax` (`.github/workflows/ci.yml`) runs them with the release of
  hax, on the aeneas and charon of `nix build .#aeneas`, and fails if the
  extraction changes the committed outputs.
- `make verify-hax` builds the extracted code against the Lean libraries
  (`Hax`, `CoreModels`) of that hax, which must build against this aeneas:
  Lean modules, on aeneas's Lean toolchain (hax `main` does since 721d1a27,
  2026-11-04, and so does the 0.5.0 release).

## Rebase notes

- `tests/hax` replaced `tests/src/hax_specs` and the `tests/src/hax_specs_*`
  known failures (and the vendored `hax-lib` of the nix check,
  `haxSpecsVendor`). Tests that upstream-port commits add to
  `tests/src/hax_specs` belong in a module of `tests/hax/src/specs/` (e.g.
  `mutual.rs`, from the 2026-10-20 rebase; failures: a crate in
  `tests/hax/failures`), and the outputs must be re-extracted with
  `make extract-hax`.
- A bump of `backends/lean/lean-toolchain` must also update
  `tests/hax/proofs/hax-tests/lean/lean-toolchain` (`make verify-hax` checks
  it).
- The proof check of `scripts/test-hax.sh` (`verify`: every obligation of
  `Extraction/ProofObligations.lean` has a theorem of the same name under
  `Verification/`, without `sorry`) compares names only. Once hax runs Lean's
  comparator (which checks that the handwritten theorems state the extracted
  obligations and use no extra axioms), use it instead and drop this check.

## History

- 2026-10-07: bootstrapped from fork PRs #7, #58, #62; ported to upstream's
  removal of LLBC builtin functions (#1320) and module-system output (#1230).
- 2026-10-20: ported to the removal of `replace_static` (#1438) and the
  promoted-constant pre-passes (#1404); the late-skip filter keeps its place
  after `filter_type_aliases`.
- 2026-10-23: the `step`-style backend (`-specs hax-step`, its test
  `tests/src/hax_specs_step` and the `@[spec]` attribute on obligations) removed
  (fork PR #76).
- 2026-10-23: unit arguments are kept in specs and obligations (fork PR #79).
- 2026-10-23: the trait clauses of the conditions of trait methods are matched
  with the method's, supertrait clauses through parent clauses (fork PR #80).
- 2026-10-23: the names generated for specs are registered, and clashes are
  errors (fork PR #82).
- 2026-10-23: the tests moved to `tests/hax`, extracted end-to-end with
  `cargo hax` (fork PR #83).
- 2026-11-04: rebased on the 2026-11-02 dev (no change).
