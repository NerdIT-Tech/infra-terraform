# ADR-0015: `terraform-pr.yml`'s path filter must be a superset of `terraform-apply.yml`'s

**Status:** Superseded by ADR-0024 — amends 0004
**Date:** 2026-07-26

> **Superseded by ADR-0024:** `terraform-pr.yml` now runs on *every* PR (no
> path filter) so the required `Plan` check always reports, with the
> `validate`/`plan` jobs short-circuiting to a no-op when no terraform files
> changed. The superset invariant this ADR establishes still holds — now
> trivially, since the PR workflow is unconditional — but the mechanism (a
> `paths` filter that must mirror `terraform-apply.yml`'s) no longer exists.
> See ADR-0024 instead.

## Context

`terraform-apply.yml`'s `resolve-pr` job (ADR-0004) reuses the merged PR's
reviewed `tfplan` artifact instead of re-planning after merge. That artifact
only exists if `terraform-pr.yml` ran a `plan` job on that PR.

The two workflows' `paths` filters had drifted apart: `terraform-apply.yml`
triggers on changes to its own workflow file
(`.github/workflows/terraform-apply.yml`), but `terraform-pr.yml` did not.
A PR that touched only `terraform-apply.yml` therefore never ran
`terraform-pr.yml`'s `plan` job, produced no `tfplan` artifact — but merging
it still triggered `terraform-apply.yml`, whose `plan` job resolved the
merged PR and then failed trying to download an artifact that was never
produced ("apply fails due to not finding a plan").

## Decision

`terraform-pr.yml`'s `paths` filter must be kept a **superset** of
`terraform-apply.yml`'s. Concretely, added
`.github/workflows/terraform-apply.yml` to `terraform-pr.yml`'s filter, so
any PR that would trigger an apply on merge is guaranteed to have already
produced a reviewed plan to reuse.

## Alternatives considered

- **Make `terraform-apply.yml`'s `plan` job fall back to a fresh plan when
  the reused artifact can't be found** — considered, and could additionally
  be made to fail-closed only when that fresh plan shows real changes
  (succeed on a no-op, fail loudly otherwise). Rejected for now as a
  separate concern from this fix — it's defense-in-depth for artifact
  loss/expiry, not a fix for the path-filter drift itself. Worth revisiting
  if this class of failure recurs for a reason other than a filter mismatch.
- **Drop `terraform-apply.yml` from its own path filter** — would avoid
  needing a matching entry in `terraform-pr.yml`, but then a change to the
  apply workflow itself would never get re-run on `main` after merge,
  reintroducing the exact time-of-check/time-of-use gap ADR-0003 exists to
  close for the apply pipeline's own definition.

## Consequences

- Any future path added to `terraform-apply.yml`'s filter must be mirrored
  into `terraform-pr.yml`'s (not necessarily the reverse — e.g.
  `.tflint.hcl` only affects PR-time linting, not what gets planned/applied,
  so it doesn't need a matching entry in `terraform-apply.yml`).
- This doesn't fully close the gap: an artifact can still go missing for
  other reasons (retention expiry, a cancelled `terraform-pr.yml` run on an
  otherwise-mergeable PR). Those cases still hard-fail today, by design —
  see the rejected alternative above if that needs revisiting later.
