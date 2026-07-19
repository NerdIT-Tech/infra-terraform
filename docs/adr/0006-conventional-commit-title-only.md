# ADR-0006: Lint PR titles against Conventional Commits, not every commit

**Status:** Accepted
**Date:** 2026-07-19

## Context

Wanting commit history to be machine-parseable (for changelogs, semantic
versioning, or just readability) means enforcing some convention on commit
messages. The two obvious granularities are: lint every commit on a
branch, or lint just the PR title.

## Decision

`conventional-commits.yml` lints only the **PR title** against
[Conventional Commits](https://www.conventionalcommits.org/) (`feat:`,
`fix:`, `chore:`, etc.) via `amannn/action-semantic-pull-request`, on
`pull_request_target` so it also works cleanly for PRs opened from forks.
Individual commits within a branch are never linted.

## Alternatives considered

- **Lint every commit** — catches messy intermediate commits, but punishes
  normal WIP history (`wip`, `fix typo`, `address review comments`) that's
  perfectly fine to have mid-review. Rejected as unnecessarily strict for
  how this repo's contributors actually work.

## Consequences

- Since ADR-0008 moved this repo to **squash-merge only**, the linted PR
  title *becomes* the actual commit message that lands on `main` (as long
  as GitHub's default squash commit message is configured to use the PR
  title — see ADR-0008's consequences). Title-only linting was already the
  right call under merge-commit merges, but under squash it goes from
  "linting the summary" to "linting the literal thing that ends up in
  history" — the same rule now does double duty.
- `Dependabot`'s own PRs must produce titles that pass this check too —
  that's why `.github/dependabot.yml` sets a `commit-message.prefix`
  (`chore`/`ci`) per ecosystem rather than leaving Dependabot's default
  titles as-is.
- Because this runs on `pull_request_target`, the workflow file itself is
  read from `main`, not from the PR branch — a PR can't alter or disable
  this check on itself even if it edits `conventional-commits.yml`.
