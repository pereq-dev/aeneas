# charon-pin

## Summary

Moves the charon pin (`charon-pin` and the `charon` input in `flake.lock`)
ahead of upstream's, currently to `45bab24cd`, with the adaptations of the
Aeneas sources to the charon API changes (as upstream Aeneas did in
9c5174a0c and 3cd955dd2).

## Invariants

- `charon-pin` and `flake.lock` name the same charon revision, and it
  descends from upstream's pin.

## Rebase notes

- Drop this patch once upstream's charon pin is `45bab24cd` or one of its
  descendants. Until then, resolve its conflicts by taking upstream's
  `flake.lock` and `charon-pin` and re-locking at whichever of the two pins
  descends from the other, with
  `nix flake lock --override-input charon github:AeneasVerif/charon/<rev>`.

## History

- 2026-10-20: added (as `charon-pin-macos-release`), pin moved to `44ffb203b`.
- 2026-10-26: renamed; pin moved to `45bab24cd`.
