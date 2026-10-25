# hax-trait-specs

## Summary

Extends `hax-specs` to the contracts of traits (fork PR #85). Every local trait
`X` gets a companion structure `X.Lawful` (in `Specs.lean`) with one field
`<P>InstLawful` per parent clause and one field `<m>_spec` per method with a
`#[requires]`/`#[ensures]` contract, stated over `X.<m>.pre`/`X.<m>.post`.
Every local trait impl, including derived impls and impls of foreign traits,
gets an obligation `<impl>.Lawful` (in `ProofObligations.lean`). The specs of
functions with trait clauses take a Lawful hypothesis per clause. When a trait
method has only one of `#[requires]`/`#[ensures]`, the other condition is
synthesized, with body `ok true`. Contracts on the methods of an impl are
checked as standalone specs, independent of the trait contract (with a
warning when the trait method has a contract too).

The `hax-specs` IR (`src/specs/HaxSpecs.ml`) has trait specs and impl
obligations; `src/specs/HaxProducer.ml` gathers the contracts of trait methods
and the impls; `src/extract/ExtractHaxSpecs.ml` prints the Lawful structures,
hypotheses and obligations. Unsupported contracts are dropped with a
`hax-specs:` warning rather than failing the extraction. `-specs hax` now
requires `-core-models-lib`.

The user documentation is `documentation/hax-specs.md` (overview, file
structure, diagnostics, limitations, proof recipes).

## Invariants

- Without `-specs`, the output is unchanged.
- `-specs hax` without `-core-models-lib` is a command-line error.
- `X.Lawful` is only generated for local traits: for a foreign trait, the
  generated code refers to `X.Lawful` as if it existed, and a Lean library
  (`CoreModels`) must provide it.
- `Specs.lean` lists the traits parents first; `ProofObligations.lean` lists
  the impl obligations dependencies first, then the function obligations.
- The generated `.Lawful` names are registered with the other spec names: a
  clash with a crate item (e.g. an associated type `Lawful`) is an error.
- A contract that cannot be extracted is dropped with a warning (an error
  under `-warnings-as-errors`); the extraction continues. Each entry of
  `Specs.lean`/`ProofObligations.lean` is printed only if it extracts: a
  dropped entry leaves no partial output.
- Unit arguments are passed as `()` and bound as `_`, in the specs and in the
  `Lawful` fields.
- An argument of a trait method that is not a variable in its precondition
  (e.g. `_`) is named after its type in its `Lawful` field, as in the
  functions with a body.
- The impls nested in hax's decoration fns (the `Fn*` impls of the closures
  of a contract) get no Lawful obligation.
- Lawful binder names are built from the unescaped clause names, and escaped
  when printed.
- The spec and obligation of a function without a body (e.g.
  `#[hax_lib::opaque]`) are generated as for the other functions: the value
  binders come from the signature, named after the inputs of the precondition
  (or else of the postcondition). A function mapped by `-external-names`
  (patch `external-names`) is applied by its external name, but its generated
  names are those of the Rust function.
- The triple of a spec is about a monadic program: the call of a function
  that cannot fail (e.g. mapped by `-external-names` with
  `"can_fail": false`) is wrapped in `ok`.

## Tests

- `tests/hax/src/specs/traits/` (expected outputs in
  `tests/hax/proofs/hax-tests/lean/HaxTests/Extraction`): basic contracts,
  supertraits and diamonds, generic and blanket impls, default methods,
  method, trait and const generics, associated constants and type bounds,
  `&mut self`, modules, built-in bounds, unannotated subtraits, impl-level
  contracts and synthesized conditions (the unsupported cases are commented
  out in `synthesized.rs`).
- `tests/hax/proofs/hax-tests/lean/HaxTests/Verification/Traits/`: proofs of
  the trait-level obligations. They use the `triple_prop_*` lemmas of
  `mvcgen-result-specs` on `.holds`.
- `tests/hax/src/specs/arguments.rs` (`UnitArg`, `UnnamedArg`): a unit
  argument and an unnamed argument (`_: u32`) of a trait method.
- `tests/hax/src/specs/naming.rs` (`escaped_clause`): a Lawful binder name
  that needs `«»`; `tests/hax/src/specs/contracts.rs` (`with_closure`): a
  closure in a function body keeps its Lawful obligations.
- `tests/src/hax-specs-no-core-models-lib.rs`: the `-specs hax` flag check.
- `tests/hax/src/specs/opaque.rs`: contracts of opaque functions (a caller,
  only `#[ensures]`, unit arguments, no argument, an unnamed argument, a
  trait clause), assumed in
  `Assumptions/OpaqueContracts.lean`; `is_mult` is mapped by
  `tests/hax/external-names.json` to `Assumptions/ExternalModels.lean`, and its
  obligation proved against the model; so is `is_zero`, mapped with
  `"can_fail": false` to a non-monadic model.

## Rebase notes

- Depends on `hax-specs`, `core-models-lib`,
  `trait-field-constructor-clash` (`check_trait_field_clash`),
  `external-names` (`parent_fun_name` reads `external_info`, the field of
  `Pure.fun_decl` renamed by that patch: upstream calls it `builtin_info`) and,
  for the proofs of the tests, `mvcgen-result-specs` (`triple_prop_*`); the
  tests also use `external-names` and `extra-includes`.
- The `tests/hax` outputs are produced by `cargo hax extract`: re-extract them
  with `make extract-hax HAX_DIR=<hax checkout>` and re-check the proofs with
  `make verify-hax` (see `hax-specs`).

## History

- 2026-10-23: bootstrapped from fork PR #85, rebased on the 2026-10-20 fork;
  `tests/hax/src/specs.rs` keeps `hax-specs`'s `mutual` module.
- 2026-10-25: unit arguments of the trait methods are passed as `()` in the
  Lawful fields, and unnamed arguments are named after their type (they were
  named `«_»`).
- 2026-10-25: layout of the output (symbols measured in code points, indented
  continuations), no obligations for the impls nested in decoration fns,
  escaped Lawful binder names; the Lawful field clash check reuses
  `check_trait_field_clash` (`trait-field-constructor-clash`).
- 2026-10-25: the `RustM.holds` lemmas of `Verification/Lemmas.lean` moved to
  the library (`mvcgen-result-specs`).
- 2026-10-25: contracts of functions without a body: the spec and obligation
  take their arguments from the signature (they applied the function to no
  argument); under an external name, they keep the names of the Rust
  function.
- 2026-10-25: the spec of a function that cannot fail (`"can_fail": false`
  in `-external-names`) wraps its call in `ok` (the triple was ill-typed).
