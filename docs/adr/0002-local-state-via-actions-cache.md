# ADR-0002: Persist Terraform state via the GitHub Actions cache, not a remote backend

**Status:** Accepted
**Date:** 2026-07-19 (retroactively documented; predates this ADR log)

## Context

Terraform needs somewhere durable to keep `terraform.tfstate` between CI
runs. The standard answer is a remote backend (S3, GCS, HCP Terraform,
etc.), which also gives native state locking. Standing one up is
infrastructure of its own — credentials to manage, a bucket or workspace to
provision, cost (usually negligible, but nonzero) — for a repo that, at the
time of this decision, manages a handful of `github_repository` resources.

## Decision

`terraform.tfstate` is gitignored and treated as ephemeral CI state,
persisted across runs via `actions/cache` under a single fixed key
(`terraform-state-v1`). There is no `backend` block in `versions.tf` — state
is local as far as Terraform itself is concerned.

## Alternatives considered

- **Remote backend (e.g. HCP Terraform free tier)** — the "correct" answer,
  with native locking and real durability guarantees. Rejected *for now*
  as disproportionate setup cost for this repo's current size; explicitly
  the thing to revisit once the resource count grows past a handful.
- **No persistence, replan from scratch every run** — not viable once the
  managed resources aren't safely re-creatable (e.g. once branch
  protection or non-idempotent settings are involved).

## Consequences

This is a deliberate trade-off, not the ideal setup, and it comes with
real sharp edges:

- **No native locking.** `actions/cache` has none. The only thing
  preventing a PR's read-only plan from racing an apply's write is both
  `terraform-pr.yml` and `terraform-apply.yml` sharing
  `concurrency: group: terraform-state` — if that concurrency group is ever
  removed or diverges between the two workflows, state corruption becomes
  possible.
- **No overwrite-in-place.** `actions/cache` can't update an existing key,
  so `terraform-apply.yml`'s apply job deletes the `terraform-state-v1`
  entry before saving the new one — there's a brief window with no cache
  entry at all between those two steps.
- **Weak durability.** Caches can be evicted (e.g. after 7 days of disuse).
  Mitigated by uploading `terraform.tfstate` as a 90-day build artifact
  both before and after every apply (`terraform-apply.yml`), so a lost
  cache is recoverable from the most recent artifact — but recovery is a
  manual step, not automatic.
- **Read path is safe by construction.** `terraform-pr.yml`'s plan job only
  ever restores the cache, never saves it — a PR can't corrupt state no
  matter what it plans.

Revisit this ADR (supersede it) if the number of managed resources grows
enough that a lost/corrupted cache would be genuinely costly to recover
from by hand, or if a second person starts running applies concurrently
often enough that the shared-concurrency-group mitigation starts to bite.
