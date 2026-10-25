# make-dev-fixes

## Summary

Fixes to the developer targets of the `Makefile`:

- `build-lib` runs after `build-bin`: both run `dune build` in `src`, and
  under `make -j` they failed on `_build/.lock`.
- `make format` fails when ocamlformat skips a file ("ocamlformat: ignoring
  <file>", e.g. a misplaced doc comment). `dune fmt` exits 1 both then and
  when it reformats something, and `make format` discarded both: the file
  stayed unformatted and the CI tidiness check passed.

## Invariants

- `make -j` never runs two `dune` commands in `src` at the same time.
- `make format` succeeds iff every OCaml file could be formatted; reformatting
  alone is not a failure.

## Tests

- `make -j build-dev` from a fresh `src/_build`.
- `make format` on a clean tree (no change), on a badly formatted file
  (reformatted, exit 0) and on a file with a misplaced doc comment (exit 2).

## Rebase notes

- Only touches the `Makefile`. `dune build` already builds `aeneas.cmxs`, so
  `build-lib` costs about a second after `build-bin`.
- The output of `dune fmt` is printed with `printf '%s\n'`, not `echo`: dash's
  `echo` interprets backslashes (`\c` stops the output).

## History

- 2026-10-25: created (follow-up of `hax-trait-specs`).
