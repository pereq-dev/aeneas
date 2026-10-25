# trait-field-constructor-clash

## Summary

In Lean, a trait is a structure whose constructor is `<Trait>.mk`: a trait
method (or associated item) named `mk` gives a field `<Trait>.mk`, which Lean
rejects. Field names are registered without collision checks, so this
produced invalid Lean silently. `ExtractBase.check_trait_field_clash` reports
a clash between a name and the projection of a trait field;
`extract_trait_decl_register_names` uses it for the constructor (Lean only).

## Invariants

- A trait field whose projection is named like the trait constructor is a
  name-clash error (Lean backend).
- Coq and F* are unaffected (`Foo_t_<field>` vs. `mkFoo_t`).

## Tests

- `tests/src/trait-method-mk.rs` (known failure, expected output
  `tests/src/trait-method-mk.lean.out`).

## Rebase notes

- Independent of the other patches. `hax-trait-specs` reuses
  `check_trait_field_clash` for its `<X>.Lawful` names.
- Struct fields named `mk` have the same problem and are not checked yet.

## History

- 2026-10-25: created (follow-up of `hax-trait-specs`).
