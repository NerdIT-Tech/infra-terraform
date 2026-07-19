# ADR-0007: Dependabot scoped to terraform, github-actions, and devcontainers

**Status:** Accepted
**Date:** 2026-07-19

## Context

Dependabot needs an explicit ecosystem list in `.github/dependabot.yml` —
it doesn't auto-detect what's present in a repo.

## Decision

Three ecosystems, all rooted at `/`, all weekly:

- `terraform` — provider and module version updates.
- `github-actions` — the third-party and `actions/*` versions pinned
  across `.github/workflows/*.yml`.
- `devcontainers` — the pinned feature/image versions in
  `.devcontainer/devcontainer.json` and `devcontainer-lock.json`
  (`ghcr.io/devcontainers/features/terraform`,
  `ghcr.io/roul/devcontainer-features/bitwarden-cli`, the base image).

Each ecosystem's `commit-message.prefix` is set to match Conventional
Commits (`chore` for terraform/devcontainers, `ci` for github-actions) —
see ADR-0006 for why that matters: Dependabot's PR titles have to pass the
same lint every human PR does.

## Alternatives considered

- **Just `terraform` + `github-actions`** — the more "obviously CI/infra"
  pair. Rejected in favor of also covering devcontainers, since this repo
  already pins specific feature/image versions there and letting them go
  stale silently is the same class of problem Dependabot exists to solve.

## Consequences

- Adding a new ecosystem later (e.g. if this repo ever gains an npm/pip
  component) means adding a new `updates:` entry with a matching
  `commit-message.prefix`, not just relying on Dependabot's defaults.
