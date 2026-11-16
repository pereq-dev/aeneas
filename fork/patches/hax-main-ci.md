# hax-main-ci

## Summary

The fork exists mainly to serve hax, so CI checks every aeneas change against
the latest `main` of cryspen/hax. The workflow `hax main` builds hax's Lean
proof library (`lake build` and `lake build Tests`) and extracts and builds
each hax example with a Lean target (one matrix job each), using the aeneas
and charon binaries of `nix build .#aeneas` and the Lean library in
`backends/lean` instead of the versions hax pins. `scripts/ci-hax-main.sh`
does the rewiring of the hax checkout. A PR can test against another hax
branch with a `hax-branch: <branch>` line in its description.

It runs on PRs, pushes to `dev`, nightly (to catch hax-side breakage) and
manually. The check is informational, not a required status: a failure means
hax will need adapting when it next bumps its aeneas pin.

## Invariants

These are assumptions about hax that the script checks and fails on loudly:

- hax's `hax-lib/proof-libs/lean/lakefile.toml` requires aeneas with a
  `git = …aeneas…` line directly followed by its `rev = …` line; the script
  replaces both with a `path` source.
- hax applies the `[tools]` and `[versions]` pins of `examples/hax.toml` to
  every example; neither it nor an example's own `hax.toml` already has these
  tables.
- An example is tested if its `Makefile` has a `lean:` target, and builds
  with `make clean lean` inside hax's `ci-examples` dev shell.

And about aeneas:

- `nix build .#aeneas` puts `aeneas` and `charon` in `bin`, and `charon`
  resolves to charon's own package, which has `charon-driver` next to it
  (hax requires that).
- `backends/lean/lean-toolchain` names the Lean toolchain for hax's Lean
  packages.

## Tests

- The workflow can only be tested on GitHub directly.

## Rebase notes

- Upstream has no workflow of its own for hax, so conflicts are unlikely. If
  upstream changes the `aeneas` flake output or the location of the Lean
  library, adapt the workflow and the script.
- A failing run after a rebase may come from hax `main` rather than from the
  rebase; compare with the nightly run on the old `dev`.
