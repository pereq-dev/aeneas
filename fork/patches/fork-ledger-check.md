# fork-ledger-check

## Summary

The rebase of the fork relies on its patch ledger: every fork commit carries
exactly one `Fork-Patch: <patch-name>` trailer, and every patch has a
description file `fork/patches/<patch-name>.md`. This patch checks the ledger
in CI, so that a missing trailer or a forgotten description update is noticed
in the PR rather than at the next rebase.

`fork/scripts/check-ledger.py` implements the rules and documents them in its
docstring. It has two modes:

- `pr` checks a pull request, or a merge group of the merge queue. Every
  commit must have exactly one trailer and no commit may be a merge.
  Each commit may only change the description file of its own patch, and
  every patch the PR names must have its description file added or changed
  by one of its commits. A PR cannot drop a patch; that only happens in a
  rebase of the fork. A PR that doesn't contain the fork commits of `dev`
  (its merge base with `dev` is an upstream commit), or that contains commits
  of an old `dev-YYYY-MM-DD` branch, gets a single violation with the command
  that rebases it.
- `stack` checks a whole fork stack: one trailer per commit, a description
  file for every named patch and a named patch for every description file,
  and with `--adjacent` that each patch's commits are adjacent.

The workflow `Fork ledger` (`.github/workflows/fork-ledger.yml`) runs PR mode
on PRs to `dev` and on the merge groups of `dev`'s merge queue, and stack mode
on pushes to `dev`, on manual runs, and (with `--adjacent`) on draft PRs from
`dev-YYYY-MM-DD-rebased` branches of the fork itself. It runs on GitHub-hosted
runners without nix.

## Invariants

- PRs land on `dev` through a merge queue, which may squash them into a
  commit whose message GitHub builds. The PR check only sees the PR's own
  commits, so the merge-group check is the one that guards what lands on
  `dev`; it must be a required check of the queue.
- Rebases keep the old `dev` as a branch `dev-YYYY-MM-DD` and name the new
  one `dev-YYYY-MM-DD-rebased`. The checker uses the old branches to
  recognise PRs based on a pre-rebase `dev`, and the workflow uses the new
  branch's name to check rebase PRs in stack mode. Stack mode skips the PR
  rules, so it applies only to draft PRs whose branch is in the fork itself.

## Tests

- None; the workflow can only be tested on GitHub. Running
  `fork/scripts/check-ledger.py stack --upstream upstream/main --head origin/dev`
  checks the current `dev`.

## Rebase notes

- The patch touches no upstream file, so conflicts are not expected.

## History

- 2026-11-16: created.
