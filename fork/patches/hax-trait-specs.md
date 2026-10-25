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
hypotheses and obligations. Most unsupported contracts are dropped with a
`hax-specs:` warning. A spec or an obligation that fails to extract is
reported as an error and skipped (exit code 1), and the rest of the file is
still generated. `-specs hax` now requires `-core-models-lib`.

The user documentation is `documentation/hax-specs.md` (overview, file
structure, diagnostics, limitations, proof recipes).

## Invariants

- Without `-specs`, the output is unchanged.
- `-specs hax` without `-core-models-lib` is a command-line error.
- `X.Lawful` is only generated for local traits: for a foreign trait, the
  generated code refers to `X.Lawful` as if it existed, and a Lean library
  (`CoreModels`) must provide it.
- The contract of a trait method, required or provided, is read from the
  method entry of the trait: it gives `<Trait>.<m>.pre`/`.post` and the field
  `<m>_spec` of `<Trait>.Lawful`. A provided method `<Trait>.<m>.default` gets
  no spec or obligation of its own (`HaxProducer` ignores its copy of the
  contract): its contract is checked for each impl that keeps it, in
  `<impl>.Lawful` (`specs/traits/default_methods.rs`). This supersedes two
  invariants of `hax-specs`.
- `Specs.lean` lists the traits parents first; `ProofObligations.lean` lists
  the impl obligations dependencies first, then the function obligations.
- The generated `.Lawful` names are registered with the other spec names: a
  clash with a crate item (e.g. an associated constant `Lawful`) is an error.
- A contract that cannot be extracted is either dropped with a warning (an
  error under `-warnings-as-errors`) or, if its spec or obligation fails at
  emission (e.g. a trait with an associated type and a method with a type
  parameter), reported as an error (exit code 1). In both cases the
  extraction continues. Each entry of `Specs.lean`/`ProofObligations.lean` is
  printed only if it extracts: a skipped entry leaves no partial text of its
  own (`skip_on_failure`), but the entries that refer to it are still printed
  (see Diagnostics in `documentation/hax-specs.md`).
- Unit arguments are passed as `()` and bound as `_`, in the specs and in the
  `Lawful` fields.
- An argument of a trait method that is not a variable in its precondition
  (e.g. `_`) is named after its type in its `Lawful` field, as in the
  functions with a body.
- The impls nested in hax's decoration fns (the `Fn*` impls of the closures
  of a contract) get no Lawful obligation.
- Lawful binder names are built from the unescaped clause names, and escaped
  when printed.

## Tests

- `tests/hax/src/specs/traits/` (expected outputs in
  `tests/hax/proofs/hax-tests/lean/HaxTests/Extraction`): basic contracts,
  supertraits and diamonds, generic and blanket impls, default methods,
  method, trait and const generics, associated constants and type bounds,
  `&mut self`, modules, built-in bounds, unannotated subtraits, impl-level
  contracts and synthesized conditions (the unsupported cases are commented
  out in `synthesized.rs`).
- `tests/hax/proofs/hax-tests/lean/HaxTests/Verification/Traits/`: proofs of
  the trait-level obligations; `Verification/Lemmas.lean` holds the
  `RustM.holds_bool` simp lemma they use.
- `tests/hax/src/specs/arguments.rs` (`UnitArg`, `UnnamedArg`): a unit
  argument and an unnamed argument (`_: u32`) of a trait method.
- `tests/hax/src/specs/contracts.rs` (`with_closure`): a closure in a function
  body keeps its Lawful obligations.
- `tests/hax/src/specs/naming.rs` (`escaped_clause`): a Lawful binder name
  that needs `«»`.
- `tests/src/hax-specs-no-core-models-lib.rs`: the `-specs hax` flag check.
- `tests/hax/failures/clash_lawful`: the associated constant `Lawful` of a
  trait `Foo` clashes with the generated `Foo.Lawful` (fatal).
- `trait_generics.rs` (`SubGs<T>: Gs<T>`, `use_parent`): the substitution of
  the generics of a parent clause in `parent_ref` (used by `cond_generics`'
  `with_parents` and the `<P>InstLawful` parent fields), at an impl's and a
  caller's arguments.

## Rebase notes

- Depends on `hax-specs` and `core-models-lib`.
- The `tests/hax` outputs are produced by `cargo hax extract`: re-extract them
  with `make extract-hax` and re-check the proofs with
  `make verify-hax` (see `hax-specs`).
- `ExtractSpec.skip_on_failure` prints each entry in a buffer formatter of
  its own, which must measure strings like the formatter of the file
  (`FormatCompat.use_byte_width`): otherwise the layout of `Specs.lean` and
  `ProofObligations.lean` depends on the OCaml version.

## History

- 2026-10-23: bootstrapped from fork PR #85, rebased on the 2026-10-20 fork;
  `tests/hax/src/specs.rs` keeps `hax-specs`'s `mutual` module.
- 2026-10-25: unit arguments of the trait methods are passed as `()` in the
  Lawful fields, and unnamed arguments are named after their type (they were
  named `«_»`).
- 2026-10-25: layout of the output (symbols measured in code points, indented
  continuations).
- 2026-10-25: no Lawful obligations for the impls nested in decoration fns.
- 2026-10-25: escaped Lawful binder names.
- 2026-11-04: rebased on the 2026-11-02 dev; since upstream's move to
  OCaml 5.4+ (`Format` measures strings in code points), the buffer
  formatter of `ExtractSpec.skip_on_failure` measures them in bytes with
  upstream's `FormatCompat.use_byte_width`, as the file formatters do.
