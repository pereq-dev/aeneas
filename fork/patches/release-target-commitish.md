# release-target-commitish

## Summary

The release workflow's "Create Release" step passes
`target_commitish: ${{ github.sha }}`. Without it, `softprops/action-gh-release`
creates the new tag on the default branch's HEAD, so a release dispatched from
another branch is named `build-<branch sha>` but its tag points at `dev`.

## Invariants

- A release's tag points at the commit the release was built from.

## Tests

- Can only be tested directly on GitHub.

## Rebase notes

- Drop this patch if upstream's "Create Release" step sets
  `target_commitish` itself.

## History

- 2026-11-16: added.
