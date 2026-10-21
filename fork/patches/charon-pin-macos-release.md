# charon-pin-macos-release

## Summary

Moves the charon pin (`charon-pin` and the `charon` input in `flake.lock`)
from `de8736f7` to `44ffb203b`, so that the release build works on macOS.

Upstream pins `de8736f7` (#1466), the head of charon PR #1540 before it was
merged. That revision lacks charon's "Fix macos release" (charon PR #1536):
since charon's "Speedup CI" (#1532), its nix build runs
`target/release/generate-asts` directly instead of through `cargo run`, so on
macOS `charon-driver` no longer finds `librustc_driver`
(`dyld: … no LC_RPATH's found`), and the `aeneas-macos-aarch64` job of the
Release workflow fails. Upstream's nightly Release has failed this way since
2026-10-16.

`44ffb203b` is the commit that merged #1540 into charon's `main`. It descends
from `de8736f7` and adds only charon PRs #1536 (the macOS fix), #1537
(recovering from panics and stack overflows in transformations) and #1539
(applying presets before validation options).

## Invariants

- `charon-pin` and `flake.lock` name the same charon revision, and it
  descends from upstream's pin (CI checks that the pin only moves forward and
  is merged into charon's `main`).

## Tests

- The release build on macOS (Release workflow, `aeneas-macos-aarch64`).
- `aeneas-tests`: the test outputs are re-extracted with the new charon.

## Rebase notes

- Drop this patch once upstream's charon pin is `44ffb203b` or one of its
  descendants. Until then, resolve its conflicts by taking upstream's
  `flake.lock` and `charon-pin` and re-locking at whichever of the two pins
  descends from the other, with
  `nix flake lock --override-input charon github:AeneasVerif/charon/<rev>`.

## History

- 2026-10-20: added after the 2026-10-20 rebase, for the release build on
  macOS.
