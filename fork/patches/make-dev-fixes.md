# make-dev-fixes

## Summary

Fixes to the developer targets of the `Makefile`:

- `build-lib` runs after `build-bin`: both run `dune build` in `src`, and
  under `make -j` they failed on `_build/.lock`.

## Invariants

- `make -j` never runs two `dune` commands in `src` at the same time.

## Tests

- `make -j build-dev` from a fresh `src/_build`.

## Rebase notes

- Only touches the `Makefile`. `dune build` already builds `aeneas.cmxs`, so
  `build-lib` costs about a second after `build-bin`.

## History

- 2026-10-25: created (follow-up of `hax-trait-specs`).
