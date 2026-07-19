# Architecture Decision Records

Each file here records one deliberate architectural or process trade-off in
this repo: what was decided, what alternatives were rejected, and what it
obligates future changes to respect. This is the authoritative home for
"why" in this repo — `README.md` covers "what" and "how to run it."

Start a new ADR from `template.md` when a real trade-off gets decided (not
for routine bug fixes or anything already fully explained by a commit
message). Prefer a new ADR that supersedes/amends an old one over editing
history — see ADR-0004 for an example of amending ADR-0003.

| # | Title | Status |
|---|-------|--------|
| [0001](0001-github-app-auth.md) | Authenticate to GitHub as a GitHub App, not a PAT | Accepted |
| [0002](0002-local-state-via-actions-cache.md) | Persist Terraform state via the Actions cache, not a remote backend | Accepted |
| [0003](0003-plan-gated-apply-pipeline.md) | Gate every apply behind a reviewer-approved, frozen plan artifact | Accepted |
| [0004](0004-reuse-pr-plan-on-merge.md) | Reuse the PR's reviewed plan on merge instead of re-planning | Accepted — amends 0003 |
| [0005](0005-sticky-pr-plan-comment.md) | Sticky, self-deleting PR plan comment | Accepted |
| [0006](0006-conventional-commit-title-only.md) | Lint PR titles against Conventional Commits, not every commit | Accepted |
| [0007](0007-dependabot-scope.md) | Dependabot scoped to terraform, github-actions, devcontainers | Accepted |
| [0008](0008-squash-merge-only.md) | This repo merges PRs via squash-merge only | Accepted |
| [0009](0009-one-module-per-repo.md) | One Terraform module call per managed repository | Accepted |
