# ADR-0009: One Terraform module call per managed repository

**Status:** Accepted
**Date:** 2026-07-19 (retroactively documented; predates this ADR log)

## Context

This repo will grow to manage more than one GitHub repository, and
possibly more asset types beyond repos (teams, org membership) later. Each
repo needs roughly the same shape of configuration: a `github_repository`
resource plus optional branch protection.

## Decision

`modules/github-repository/` wraps `github_repository` and its branch
protection in one reusable module. Every repo this org manages is exactly
one `module` block in `repositories.tf`, configured via the module's
variables — never a copy-pasted `resource "github_repository"` block.

## Alternatives considered

- **A `resource "github_repository"` block per repo, copy-pasted and
  tweaked** — faster to write the first time, but drifts: a fix or new
  default (e.g. the squash-merge-only default from ADR-0008) has to be
  hand-applied to every copy instead of landing once in the module.

## Consequences

- Adding a repo is "copy the module block, change the name and arguments"
  (see README.md's "Adding a repository" section) — not writing resource
  config from scratch.
- A module default change (e.g. adjusting `required_approving_review_count`)
  applies to every repo using that default the next time `apply` runs —
  worth double-checking the plan output for repos that didn't explicitly
  override it.
