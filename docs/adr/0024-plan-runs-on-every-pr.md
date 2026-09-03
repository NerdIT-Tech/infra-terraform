# ADR-0024: `terraform-pr.yml` runs on every PR so the required `Plan` check always reports

**Status:** Accepted — supersedes the path-filter mechanism of 0015
**Date:** 2026-09-03

## Context

`Plan` is a **required status check** for `main` (`repositories.tf`), sourced
from the `plan` job's `name: Plan` in `terraform-pr.yml`. But that workflow
was path-filtered to terraform files (`**.tf`, `.terraform.lock.hcl`,
`.tflint.hcl`, the two terraform workflows). A PR that didn't touch any of
those — e.g. a workflow/action/docs-only change — never ran the workflow, so
the `Plan` job never ran, so the `Plan` status was never reported. Under
`strict` branch protection, a required check that never reports leaves the PR
permanently unreportable and forces a manual **bypass** on every such PR.

That's a real, recurring cost: this repo routinely merges workflow and docs
changes (PR title lint, yaml/action lint, dependabot config, ADRs), and each
one required an admin bypass of a check that was structurally guaranteed to
never run. Needing a bypass isn't an assertion that "this is fine, skip the
gate" — it's an assertion that the gate is misconfigured to never fire for an
entire class of PR it's supposed to govern.

## Decision

`terraform-pr.yml` drops its `paths:` filter and runs on **every** PR. To
avoid paying a full AWS-backed `terraform plan` (OIDC role assumption, state
read, lock) on PRs that don't touch terraform, both the `validate` and `plan`
jobs first run a `dorny/paths-filter@v4` step that detects whether any
terraform-relevant file changed:

- `**.tf`
- `.terraform.lock.hcl`
- `.tflint.hcl`

When none changed, the `validate` job skips `terraform-lint-scan` and the
`plan` job skips `terraform-init-s3` / `terraform-plan` /
`terraform-release-lock` — but the jobs still complete successfully, so the
`Plan` status is **always** reported (as success) and branch protection never
blocks.

When terraform files did change, behavior is unchanged: full lint/plan, with
the reviewed `tfplan` artifact uploaded for ADR-0004's reuse-on-merge.

## Alternatives considered

- **Keep the path filter and accept the bypass** — the status quo the PR
  was fixing. Rejected: it's the bug, not a trade-off — it forces a human
  bypass with every workflow/docs-only merge.
- **Add a separate always-on reporting job named `Plan`** that emits success
  when nothing changed, keeping the real plan path-filtered. More workflow
  surgery (two `Plan`-named statuses, dedup risk) for the same outcome as
  just running the existing job and short-circuiting its terraform steps.
- **Move `Plan` out of required checks / make required checks conditional on
  changed paths** — GitHub doesn't support condition-required checks, so a
  docs-only PR would silently gain no gate at all, which is the opposite
  problem (ADR-0003's spirit is that every apply is plan-gated, and a
  none-apply PR still isn't a reason to have zero required signal).

## Consequences

- `terraform-pr.yml` now fires on every PR, so the `Plan` check (and `Format,
  validate, lint, scan`) is always present and green on terraform-unrelated
  PRs — no more bypass needed for them. ADR-0015's superset invariant (every
  apply-able PR was planned) still holds, now trivially since the PR workflow
  runs everywhere.
- Any future `paths`/filter added to `terraform-apply.yml` no longer needs
  mirroring into `terraform-pr.yml`: the PR workflow is unconditional, so
  the ADR-0015 mirroring obligation is gone. Keep the `dorny/paths-filter`
  `terraform` filter in `terraform-pr.yml` in sync with the set of files that
  actually require planning (a `.tf` change is what matters).
- The `dorny/paths-filter` `terraform` glob is the single source of truth for
  "does this PR need a plan" and is duplicated in both the `validate` and
  `plan` jobs — keep the two in step (they must agree, since `validate` gates
  lint/scan and `plan` gates the AWS plan).
- A skipped-no-op `plan` produces no `tfplan` artifact (`steps.plan.outputs`
  are empty), which is correct: `terraform-apply.yml` only runs on terraform
  changes and only reuses a PR's artifact when one was produced.
- Introduces `dorny/paths-filter@v4` (a new third-party action) to this repo;
  it's added to the `github-actions` ecosystem Dependabot tracks. Pin to the
  same floating-major-tag convention as the other third-party actions here.
