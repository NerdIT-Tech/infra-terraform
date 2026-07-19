# ADR-0004: Reuse the PR's reviewed plan on merge instead of re-planning after merge

**Status:** Accepted — amends ADR-0003
**Date:** 2026-07-19

## Context

`terraform-pr.yml` already produces a `terraform plan` on every PR and
posts it as a comment for human review. Under ADR-0003's original design,
though, `terraform-apply.yml` recomputed its *own* plan from scratch after
the PR merged — meaning the plan a reviewer actually looked at on the PR
and the plan that gets applied after merge could silently differ (state
could have moved between review and merge, or the diff itself could have
changed if the branch wasn't up to date). ADR-0003 closed the gap between
"approve" and "apply" within a single workflow run; this ADR closes the
same kind of gap across the PR-to-merge boundary.

## Decision

`terraform-pr.yml`'s plan job now also uploads its `tfplan` as a build
artifact. `terraform-apply.yml` gained a `resolve-pr` job that, for every
push to `main`, asks GitHub's "list pull requests associated with a commit"
API whether this push is a merged PR (`merge_commit_sha` matches). If so,
the `plan` job **downloads that PR's already-reviewed `tfplan` artifact**
(via `dawidd6/action-download-artifact`) instead of running `terraform
plan` again. Direct pushes to `main` and `workflow_dispatch` runs have no
associated PR and fall back to planning fresh — the original ADR-0003
behavior.

## Alternatives considered

- **Keep re-planning after merge (status quo)** — simpler, but leaves the
  review-vs-apply gap described above. Rejected once plan-reuse became
  feasible.
- **Always require a fresh plan and just diff it against the PR's plan,
  failing if they differ** — more robust in theory, but meaningfully more
  complex to implement (structured plan diffing) for a repo this size.
  Rejected as disproportionate; see the staleness handling below instead.
- **Silently fall back to a fresh plan if the reused one is stale** —
  rejected: a stale-plan `terraform apply` failure is a *feature* here, not
  a bug to be silently routed around. If the saved plan no longer matches
  reality, apply should fail loudly and force a human to look, not quietly
  apply a different plan than the one that was reviewed.

## Consequences

- Requires branch protection to require PR branches be **up to date before
  merging** — this is what keeps "the plan went stale between review and
  merge" rare in practice. Without it, a PR's plan could be reviewed
  against state that's since moved (e.g. because another PR merged and
  applied first), and the reused plan would fail at apply time.
- `terraform apply` refuses a saved plan file whose configuration/state
  fingerprint has moved since it was created ("stale plan"). When that
  happens here, the fix is `workflow_dispatch` to plan and apply fresh —
  there's no auto-recovery path, by design (see above).
- This mechanism is why `terraform-pr.yml`'s plan job must keep uploading
  `tfplan` as an artifact — if that upload step is ever removed, merges
  silently fall back to the ADR-0003 fresh-plan path for every PR, quietly
  losing the guarantee this ADR exists to provide.
- Squash-merging a PR still produces a `merge_commit_sha` that GitHub's
  association API resolves correctly back to the source PR, so this
  mechanism is unaffected by ADR-0008's move to squash-only merges.
