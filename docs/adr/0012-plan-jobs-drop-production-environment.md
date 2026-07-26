# ADR-0012: Plan jobs don't declare `environment: production`; only apply does

**Status:** Accepted
**Date:** 2026-07-25

## Context

While turning on the new OIDC-based AWS auth from [ADR-0010](0010-s3-state-backend.md),
`terraform-pr.yml`'s `plan` job failed to assume the `plan` IAM role with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`, even though the
role ARN and `bootstrap/main.tf`'s trust policy both looked correct.

The cause: that job (and both jobs in `terraform-apply.yml`) declared
`environment: production`, added in an earlier fix
(`8aac494`, "scope Plan job to production environment for GitHub App
secrets") because `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/
`TF_GITHUB_APP_PEM` were stored as secrets/variables scoped to the
`production` GitHub Environment, not the repo. That fix was correct for its
own problem (the job silently got empty credentials without it), but it has
a side effect that wasn't accounted for when `plan_trust`'s subject
condition was written: **a job that declares `environment: X` gets an
OIDC `sub` claim of `repo:OWNER/REPO:environment:X` instead of the usual
event-based one (`pull_request`, `ref:refs/heads/BRANCH`) — it replaces it,
it doesn't add to it.**

With all three jobs (`terraform-pr.yml`'s `plan`, `terraform-apply.yml`'s
`plan` and `apply`) declaring the same environment, all three would present
the *identical* subject claim to AWS. Widening `plan_trust` to also accept
`environment:production` would have "fixed" the auth failure while
destroying the actual security property ADR-0002/ADR-0010 are built on: a
read-only role a PR plan can safely assume, distinct from a read-write role
it can't. If both roles trust the same subject, a PR could edit
`terraform-pr.yml` to request the apply role's ARN instead of the plan
role's and succeed — the IAM trust boundary can't tell the two jobs apart
once their claims are identical, so the separation would exist only as an
unenforced convention in the workflow YAML.

## Decision

- `GITHUB_APP_ID`/`GITHUB_APP_INSTALLATION_ID`/`TF_GITHUB_APP_PEM` move to
  repo-level Secrets/Variables (`Settings → Secrets and variables →
  Actions`, not under an Environment) — nothing about them is
  apply-specific, so they don't need environment scoping at all.
- `environment: production` is removed from both `plan` jobs. Their OIDC
  subject reverts to the event-based claim (`pull_request` for
  `terraform-pr.yml`, `ref:refs/heads/main` for `terraform-apply.yml`'s
  plan, which only runs on push to `main` or `workflow_dispatch`) —
  matching what `plan_trust` in `bootstrap/main.tf` already expected.
- `environment: production` stays on `terraform-apply.yml`'s `apply` job
  only — that's where [ADR-0003](0003-plan-gated-apply-pipeline.md)'s
  actual reviewer-approval gate belongs, and it's the only job that should
  ever get the environment-scoped subject.
- `apply_trust`'s condition in `bootstrap/main.tf` changes from
  `repo:OWNER/REPO:ref:refs/heads/main` (which, per the above, would never
  actually match) to `repo:OWNER/REPO:environment:production`.

## Alternatives considered

- **Add `environment:production` to `plan_trust` too** — the naive fix.
  Rejected: collapses the plan/apply trust distinction, as explained above.
- **Give `plan_trust` both the event-based subjects AND
  `environment:production`** — same problem as above; the moment
  `plan_trust` accepts `environment:production`, so does every job that can
  present that claim, including a would-be attacker's edited plan job.
- **Keep the secrets environment-scoped, add a second, narrower environment
  just for plan** (e.g. `plan-readonly`, no required reviewers) — would
  have preserved distinct subjects without moving secrets, but adds a
  second Environment to configure and reason about for no benefit over
  just moving three non-sensitive-to-repo-scope secrets/vars up a level.

## Consequences

- If any job is ever given `environment: production` for a new reason
  (another secret, another gate), its OIDC subject silently becomes
  `environment:production` too — re-litigate against `plan_trust` and
  `apply_trust` before assuming that's harmless. This is the mistake this
  ADR exists to prevent repeating.
- `bootstrap/README.md`'s "Wiring the root config to this backend" step and
  the root `README.md`'s CI setup instructions should list
  `TF_GITHUB_APP_ID`/`TF_GITHUB_APP_INSTALLATION_ID`/`TF_GITHUB_APP_PEM` as
  repo-level, not environment-scoped, going forward.
- Changing `apply_trust` requires re-applying `bootstrap/` by hand (see
  `bootstrap/README.md`) — it doesn't take effect until that's done.
