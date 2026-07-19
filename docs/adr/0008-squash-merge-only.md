# ADR-0008: This repo merges PRs via squash-merge only

**Status:** Accepted
**Date:** 2026-07-19

## Context

`infra-terraform` had been merging PRs via merge commits (`Merge pull
request #N from ...`). That's inconsistent with the house style this repo
itself enforces on every *other* repo it manages: `modules/github-repository`
already defaults new repos to `allow_squash_merge = true`,
`allow_merge_commit = false`, `allow_rebase_merge = false`. Squash-only was
already the intended org standard; `infra-terraform` just hadn't been
brought in line with its own default.

## Decision

Squash-merge only for `infra-terraform`: disable "Allow merge commits" and
"Allow rebase merging" in the repo's GitHub settings, keep "Allow squash
merging" as the sole option, and set the default squash commit message to
the **pull request title** (not the concatenated commit list).

## Alternatives considered

- **Keep merge commits** — status quo; rejected as inconsistent with the
  org standard this repo itself defines for every other managed repo.
- **Self-manage this repo's own settings via its own Terraform module**
  (add a `module "infra_terraform"` block to `repositories.tf`, same as
  `servicenow_sdk_for_go`) — appealing (this repo would then eat its own
  dog food), but deferred: doing it safely requires `terraform import`-ing
  the existing repo and branch protection into state first, and the
  module's defaults (`require_signed_commits = true`,
  `enforce_admins = false`) don't necessarily match this repo's actual
  current configuration — applying blind could lock out unsigned pushes or
  otherwise surprise-diff settings nobody meant to change. Worth doing
  later as its own deliberate, reviewed step — not as a side effect of
  this ADR.
- **Rebase merging** — keeps a linear history without squashing, but
  doesn't give a single canonical commit message the way squash does, so
  it doesn't pair as cleanly with ADR-0006's PR-title lint.

## Consequences

- **Manual step required, done outside of Terraform**: in GitHub, go to
  **Settings → General → Pull Requests** and (a) uncheck "Allow merge
  commits", (b) uncheck "Allow rebase merging", (c) set "Default commit
  message for squash merges" to **"Pull request title"**. Leaving (c) at
  GitHub's own default pastes every intermediate commit subject
  (`wip`, `fix typo`, ...) into the squash commit body, which defeats the
  "clean history" motivation for this change.
- ADR-0004's plan-reuse-on-merge mechanism is unaffected: GitHub's "list
  pull requests associated with a commit" API resolves squash commits back
  to their source PR just as it does merge commits, so `resolve-pr` keeps
  working unchanged.
- ADR-0006's PR-title lint now effectively becomes the commit message
  linter for `main`'s history, not just a PR-metadata check — see that
  ADR's consequences.
- Existing open PRs (if any) at the time this setting flips should be
  re-checked once merged, to confirm the squash commit message came out as
  expected.
