# ADR-0003: Gate every apply behind a reviewer-approved, frozen plan artifact

**Status:** Accepted
**Date:** 2026-07-19 (retroactively documented; predates this ADR log)

## Context

Once Terraform runs in CI against real GitHub org resources, something has
to decide when `terraform apply` is allowed to run, and against what plan.
The naive approach — plan and apply in the same job, on every push to
`main` — means nobody ever sees the plan before it executes.

## Decision

Split `terraform-apply.yml` into a `plan` job and an `apply` job:

- `plan` runs `terraform plan -out=tfplan`, writes the human-readable plan
  to the job summary, and uploads `tfplan` (plus the pre-apply state) as
  build artifacts.
- `apply` runs under the **`production` GitHub Environment**, which is
  configured with a required reviewer. The job doesn't start until someone
  approves it — with the plan already visible in the previous job's
  summary. Once approved, it **downloads the exact `tfplan` artifact** the
  plan job produced and runs `terraform apply ... tfplan` — never a plan
  recomputed at apply time.

Nothing auto-applies unattended: `workflow_dispatch` and direct pushes to
`main` go through the identical gate.

## Alternatives considered

- **Plan and apply in one job, no gate** — fastest, but means every push to
  `main` immediately mutates live org repos/branch-protection with zero
  human check. Rejected outright given the GitHub App's write access to
  repo administration.
- **Re-run `terraform plan` immediately before `apply`, right after
  approval, instead of reusing the artifact** — this reintroduces a
  time-of-check/time-of-use gap: the reviewer approves one plan, but a
  *different* plan (computed moments later, against whatever state exists
  by then) is what actually executes. Rejected — see ADR-0004 for how this
  same principle later extended to reusing the PR's plan across the merge
  boundary too.
- **A single required reviewer with no self-approval exception** — see the
  note below on solo maintenance.

## Consequences

- Every apply costs one click (approving the environment). For a
  single-maintainer repo, that reviewer is currently the same person
  merging the change — this is **still worth keeping**: the gate isn't
  standing in for independent peer review here, it's a deliberate forced
  pause to actually read the plan against production before it runs,
  catching fat-fingered merges or unexpected diffs that PR review (which
  approves the *code*, not the *plan output*) wouldn't. Removing it would
  make the environment's required-reviewer setting the only remaining
  unattended-apply safeguard, and there'd be none left.
- The frozen-plan-artifact mechanism is exactly what ADR-0002's state cache
  fragility depends on for safety: since state isn't lock-protected, having
  apply operate on a plan snapshot rather than re-reading live state at the
  last second closes off one more race window.
- This is the mechanism ADR-0004 (plan reuse across a PR merge) extends —
  read that ADR before changing how `plan`/`apply` source their `tfplan`.
