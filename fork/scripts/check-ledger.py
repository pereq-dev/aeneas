#!/usr/bin/env python3
"""Check the fork's patch ledger: `Fork-Patch:` trailers and description files.

The cryspen/aeneas fork carries its changes to upstream Aeneas as *patches*.
Every commit of the fork carries exactly one trailer

    Fork-Patch: <patch-name>

and every patch has a prose description file `fork/patches/<patch-name>.md`.
The rebase of the fork onto upstream relies on this ledger. This script checks
it, either for a pull request (`pr`) or for a whole fork stack (`stack`).
Every commit that lands on `dev` must follow the rules on its own. Pull
requests land through a merge queue, whose merge groups are checked in `pr`
mode as well, with the group's base commit as `--base`.

Usage:

    check-ledger.py pr --upstream upstream/main --base <origin/dev or commit> [--head HEAD]
    check-ledger.py stack --upstream upstream/main [--head origin/dev] [--adjacent]

Exit status: 0 if the ledger is valid, 1 if it has violations, 2 on a usage or
git error.

Rules (each violation names its rule in brackets):

[trailer]
    A commit has exactly one `Fork-Patch:` trailer. Trailers are read with
    git's own parser, so the trailer must be in the last paragraph of the
    commit message.

[patch-name]
    A patch name is kebab-case: `^[a-z0-9]+(-[a-z0-9]+)*$`.

[description-exists]
    Every patch named by a trailer has `fork/patches/<patch-name>.md` at the
    head commit.

[description-lint]
    A description file starts with the line `# <patch-name>` and has a
    `## Summary` section. Other sections are free-form.

[ledger-changes]  (pr mode)
    A pull request either creates a patch (adds its description file) or
    extends patches (changes their description files, at least the History or
    Rebase notes). So every patch the PR names has its description file added
    or changed by the PR, and every description file the PR adds or changes
    belongs to a patch it names. This holds per commit: a commit only changes
    the description file of its own patch, and some commit naming a patch
    changes that patch's description file. A PR cannot drop a patch: patches
    are only dropped by a rebase of the fork. A PR that deletes a description
    file violates [description-exists] if the deleting commit names the
    patch, and [ledger-changes] otherwise.

[merge-commit]
    Fork commits are not merges, and pull requests contain none.

[stale-base]  (pr mode)
    The pull request contains the fork commits of the base branch, and no fork
    commits of an old `dev`. It is violated if
    - the merge base of the PR with the base branch is an upstream commit (an
      ancestor of the merge base of upstream and the base branch), so the PR
      contains none of the base branch's fork commits; this happens to PRs
      branched from upstream or from a `dev` from before a rebase of the fork;
    - or the PR contains a commit of an old `dev-YYYY-MM-DD` branch that is
      not on the base branch.
    Rebase only your own commits onto the base branch:

        git rebase --onto <base> <old-base>

    with `<old-base>` the last commit of your branch that is not your own. A
    plain `git rebase <base>` would replay old commits of the fork.

[orphan-description]  (stack mode)
    Every description file is named by at least one commit of the stack.

[adjacent]  (stack mode with --adjacent)
    The commits of each patch are adjacent, as they are right after a rebase.

When `GITHUB_ACTIONS` is set, violations are also emitted as workflow
annotations, and when `GITHUB_STEP_SUMMARY` is set, the report is appended to
that file.
"""

import argparse
import os
import re
import subprocess
import sys

PATCHES_DIR = "fork/patches"
PATCH_NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
OLD_DEV = re.compile(r"^dev-[0-9]{4}-[0-9]{2}-[0-9]{2}$")
TRAILER_KEY = "Fork-Patch"


class GitError(Exception):
    pass


def git(*args, input=None, check=True):
    """Run git and return its standard output."""
    proc = subprocess.run(
        ["git", *args],
        input=input,
        capture_output=True,
        text=True,
    )
    if check and proc.returncode != 0:
        raise GitError(f"git {' '.join(args)} failed:\n{proc.stderr.strip()}")
    return proc


def out(*args, input=None):
    return git(*args, input=input).stdout


def rev(r):
    """The commit that `r` names, or '' if it names none."""
    proc = git("rev-parse", "--verify", "--quiet", f"{r}^{{commit}}", check=False)
    return proc.stdout.strip() if proc.returncode == 0 else ""


def merge_base(a, b):
    return out("merge-base", a, b).strip()


def is_ancestor(a, b):
    proc = git("merge-base", "--is-ancestor", a, b, check=False)
    if proc.returncode not in (0, 1):
        raise GitError(f"git merge-base --is-ancestor failed:\n{proc.stderr.strip()}")
    return proc.returncode == 0


def plural(n):
    return f"{n} commit" + ("" if n == 1 else "s")


def short(c):
    return c[:9]


def subject(c):
    return out("log", "-1", "--format=%s", c).strip()


def describe(c):
    return f"{short(c)} ({subject(c)})"


def commit_trailers(c):
    """The `TRAILER_KEY` values of a commit, as git's trailer parser sees them."""
    text = out("log", "-1", f"--format=%(trailers:key={TRAILER_KEY},valueonly)", c)
    return [line for line in text.split("\n") if line.strip()]


def description_path(patch):
    return f"{PATCHES_DIR}/{patch}.md"


def patch_of_path(path):
    """The patch whose description file is `path`, or None for other files."""
    rest = path[len(PATCHES_DIR) + 1 :]
    if "/" in rest or not rest.endswith(".md"):
        return None
    return rest[: -len(".md")]


def file_at(commit, path):
    proc = git("show", f"{commit}:{path}", check=False)
    return proc.stdout if proc.returncode == 0 else None


class Report:
    def __init__(self):
        self.violations = []

    def add(self, rule, message):
        self.violations.append((rule, message))

    def __bool__(self):
        return bool(self.violations)

    def lines(self):
        return [f"[{rule}] {message}" for rule, message in self.violations]


def check_name(report, patch, where):
    if not PATCH_NAME.match(patch):
        report.add(
            "patch-name",
            f"{where}: patch name {patch!r} is not kebab-case "
            "(`^[a-z0-9]+(-[a-z0-9]+)*$`)",
        )
        return False
    return True


def check_trailer_count(report, values, where):
    """Check for exactly one trailer; return the patch name if there is one."""
    if not values:
        report.add("trailer", f"{where} has no `Fork-Patch:` trailer in its last paragraph")
        return None
    if len(values) > 1:
        report.add(
            "trailer",
            f"{where} has {len(values)} `Fork-Patch:` trailers "
            f"({', '.join(values)}); it must have exactly one",
        )
        return None
    return values[0] if check_name(report, values[0], where) else None


def check_description(report, head, patch):
    path = description_path(patch)
    text = file_at(head, path)
    if text is None:
        report.add("description-exists", f"patch {patch!r} has no description file `{path}`")
        return
    lint_description(report, path, patch, text)


def lint_description(report, path, patch, text):
    lines = [line.rstrip() for line in text.split("\n")]
    if lines[0] != f"# {patch}":
        report.add("description-lint", f"`{path}` must start with the line `# {patch}`")
    if "## Summary" not in lines:
        report.add("description-lint", f"`{path}` has no `## Summary` section")


def commit_changed_paths(c):
    text = out(
        "diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", c, "--", PATCHES_DIR
    )
    return [p for p in text.split("\n") if p]


def check_changed_paths(report, paths, allowed, where):
    """Check that `paths` only change description files of patches in `allowed`."""
    changed = set()
    for path in paths:
        patch = patch_of_path(path)
        if patch is None:
            report.add(
                "ledger-changes",
                f"{where} changes `{path}`, which is not a description file "
                f"(`{PATCHES_DIR}/<patch-name>.md`)",
            )
            continue
        changed.add(patch)
        if patch not in allowed:
            report.add(
                "ledger-changes",
                f"{where} changes `{path}` but doesn't name patch {patch!r}; "
                "description changes belong to the commits of their own patch",
            )
    return changed


def old_dev_refs():
    """Refs of old `dev` branches kept by rebases (`dev-YYYY-MM-DD`)."""
    refs = []
    for ref in out("for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes").split():
        if ref.startswith("refs/heads/"):
            name = ref[len("refs/heads/") :]
        else:
            parts = ref.split("/", 3)
            if len(parts) < 4:
                continue
            name = parts[3]
        if OLD_DEV.match(name):
            refs.append(ref)
    return refs


def stale_base(upstream, base, head, mb):
    """Check the [stale-base] rule for a PR with merge base `mb` with `base`.

    Return (upstream_based, old_commits, old_base):
    - upstream_based: whether `mb` is an upstream commit, i.e. the PR contains
      none of the fork commits of `base`;
    - old_commits: whether the PR contains commits of an old `dev-YYYY-MM-DD`
      branch that are not on `base`;
    - old_base: the newest of those commits, or None if there is no single one.
    """
    upstream_based = is_ancestor(mb, merge_base(upstream, base))
    refs = old_dev_refs()
    if not refs:
        return upstream_based, False, None
    # The PR's commits with their parents, and those not on any old branch.
    parents = {}
    for line in out("rev-list", "--parents", head, "--not", mb).splitlines():
        c, *ps = line.split()
        parents[c] = ps
    new = set(out("rev-list", head, "--not", mb, *refs).split())
    old = set(parents) - new
    # The old commits are closed under taking parents within the PR, so the
    # newest ones are those that are no parent of another old commit.
    tips = old - {p for c in old for p in parents[c]}
    old_base = next(iter(tips)) if len(tips) == 1 else None
    return upstream_based, bool(old), old_base


def check_merges(report, base, head):
    for c in out("rev-list", "--merges", f"{base}..{head}").split():
        report.add("merge-commit", f"commit {describe(c)} is a merge commit")


def check_commits(report, head, mb, commits):
    check_merges(report, mb, head)
    changed_by = {}
    for c in commits:
        where = f"commit {describe(c)}"
        patch = check_trailer_count(report, commit_trailers(c), where)
        allowed = {patch} if patch else set()
        changed = check_changed_paths(report, commit_changed_paths(c), allowed, where)
        if patch:
            changed_by.setdefault(patch, set()).update(changed)
    for patch in sorted(changed_by):
        check_description(report, head, patch)
        if patch not in changed_by[patch]:
            report.add(
                "ledger-changes",
                f"no commit naming patch {patch!r} adds or changes "
                f"`{description_path(patch)}`; update at least its History or Rebase notes",
            )


def run_pr(args):
    head = rev(args.head)
    base = rev(args.base)
    upstream = rev(args.upstream)
    for name, value in (("head", head), ("base", base), ("upstream", upstream)):
        if not value:
            raise GitError(f"--{name} does not name a commit")

    mb = merge_base(base, head)
    upstream_based, old_commits, old_base = stale_base(upstream, base, head, mb)
    if upstream_based or old_commits:
        report = Report()
        if old_commits:
            problem = (
                "the branch contains commits of an old `dev-YYYY-MM-DD` branch "
                f"that are not on `{args.base}`"
            )
        else:
            problem = (
                f"the branch's merge base with `{args.base}` ({short(mb)}) is an upstream "
                f"commit, so the branch contains none of the fork commits of `{args.base}`"
            )
        message = (
            f"{problem}; rebase only your own commits onto `{args.base}`: "
            f"`git rebase --onto {args.base} {short(old_base) if old_base else '<old-base>'}`"
        )
        if not old_base:
            message += ", with `<old-base>` the last commit of your branch that is not your own"
        report.add("stale-base", message)
        emit(report, f"Pull request: `{short(mb)}..{short(head)}`")
        return 1

    commits = out("rev-list", "--reverse", "--no-merges", f"{mb}..{head}").split()
    report = Report()
    if not commits:
        report.add("trailer", "the pull request has no commits")
    else:
        check_commits(report, head, mb, commits)
    emit(report, f"Pull request: {plural(len(commits))} of `{short(mb)}..{short(head)}`")
    return 1 if report else 0


def run_stack(args):
    head = rev(args.head)
    upstream = rev(args.upstream)
    if not head or not upstream:
        raise GitError("--head and --upstream must name commits")
    base = merge_base(upstream, head)
    report = Report()
    check_merges(report, base, head)
    commits = out("rev-list", "--reverse", "--no-merges", f"{base}..{head}").split()
    sequence = []
    named = set()
    for c in commits:
        patch = check_trailer_count(report, commit_trailers(c), f"commit {describe(c)}")
        sequence.append(patch)
        if patch:
            named.add(patch)
    for patch in sorted(named):
        check_description(report, head, patch)
    listing = out("ls-tree", "--name-only", head, f"{PATCHES_DIR}/")
    for path in listing.split("\n"):
        patch = patch_of_path(path) if path else None
        if patch is None or patch in named:
            continue
        report.add(
            "orphan-description",
            f"`{path}` describes patch {patch!r}, but no commit of the stack names it",
        )
        lint_description(report, path, patch, file_at(head, path) or "")
    if args.adjacent:
        seen, previous = set(), None
        for c, patch in zip(commits, sequence):
            if patch is None:
                # Reported by [trailer]; it doesn't break the patch's run.
                continue
            if patch != previous and patch in seen:
                report.add(
                    "adjacent",
                    f"commit {describe(c)} of patch {patch!r} is not adjacent to the "
                    "patch's earlier commits",
                )
            seen.add(patch)
            previous = patch
    emit(report, f"Stack: {plural(len(commits))} of `{short(base)}..{short(head)}`")
    return 1 if report else 0


def emit(report, scope):
    """Print the report, annotate it on GitHub and append it to the job summary."""
    md = ["## Fork ledger check", "", f"{scope}: " + ("**violations**" if report else "**valid**"), ""]
    md += [f"- {line}" for line in report.lines()]
    text = "\n".join(md).rstrip("\n") + "\n"
    sys.stdout.write(text)
    if os.environ.get("GITHUB_ACTIONS") == "true":
        for line in report.lines():
            print(f"::error title=Fork ledger::{escape(line)}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(text)


def escape(s):
    return s.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main():
    parser = argparse.ArgumentParser(
        description="Check the fork's `Fork-Patch:` trailers and `fork/patches/` description files.",
        epilog="The module docstring lists the rules.",
    )
    sub = parser.add_subparsers(dest="mode", required=True)
    pr = sub.add_parser("pr", help="check a pull request")
    pr.add_argument("--upstream", required=True, help="upstream `main`")
    pr.add_argument("--base", required=True, help="the branch the PR targets (`dev`)")
    pr.add_argument("--head", default="HEAD", help="the PR's head commit")
    stack = sub.add_parser("stack", help="check a whole fork stack")
    stack.add_argument("--upstream", required=True, help="upstream `main`")
    stack.add_argument("--head", default="HEAD", help="the tip of the stack")
    stack.add_argument(
        "--adjacent", action="store_true", help="require each patch's commits to be adjacent"
    )
    args = parser.parse_args()
    try:
        return run_pr(args) if args.mode == "pr" else run_stack(args)
    except (GitError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
