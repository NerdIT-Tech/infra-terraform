# ADR-0010: Migrate Terraform state to an S3 backend, in this repo

**Status:** Accepted — supersedes 0002
**Date:** 2026-07-19

## Context

[ADR-0002](0002-local-state-via-actions-cache.md) persisted
`terraform.tfstate` via the GitHub Actions cache as a deliberate,
explicitly temporary trade-off for a repo managing "a handful of
`github_repository` resources," and named its own revisit trigger: grow past
that handful, or make a lost/corrupted cache genuinely costly to recover
from by hand. That trigger has now been reached, so this ADR carries out
the revisit ADR-0002 anticipated, and also settles a question ADR-0002
didn't need to ask: where does the replacement backend's own infrastructure
(the bucket, the lock table) get created and by whom.

A remote backend also needs to exist *before* anything can point at it —
using this same repo to plan/apply the backend it's about to start using
is circular.

## Decision

- State moves to an S3 backend (`versions.tf`'s `backend "s3" {}`, partial
  configuration filled in via `-backend-config` at `terraform init` time —
  see `.github/workflows/*.yml`), with a DynamoDB table for locking.
- The backend's own infrastructure — the bucket, the lock table, the
  GitHub Actions OIDC trust — is defined in `bootstrap/` **in this same
  repo**, not a separate repository, because nothing else uses this backend
  yet (confirmed with the user when this ADR was written — revisit if that
  stops being true, see Consequences). `bootstrap/` is a distinct root
  Terraform config with its own state, applied by hand, never by CI — see
  `bootstrap/README.md` for the exact first-run procedure (local state,
  then self-migrate into the bucket it just created).
- CI authenticates to AWS via GitHub Actions OIDC (`aws-actions/configure-aws-credentials`),
  not static access keys stored as a repo secret — consistent with
  [ADR-0001](0001-github-app-auth.md)'s stance against long-lived
  credentials.
- Two IAM roles, not one, to preserve the property ADR-0002 called out as
  a benefit of the old design ("a PR can't corrupt state no matter what it
  plans"): a read-only `plan` role (assumed by `terraform-pr.yml` and by
  `terraform-apply.yml`'s `plan` job) and a read-write `apply` role
  (assumed only by `terraform-apply.yml`'s `apply` job, gated by the
  `production` environment per [ADR-0003](0003-plan-gated-apply-pipeline.md)).
  Both roles are scoped to exactly this bucket, exactly the root config's
  state key, and exactly this repo's OIDC subject claims — neither role can
  touch `bootstrap/`'s own state, which lives under a different key.

## Alternatives considered

- **Stay on the Actions cache** — rejected; ADR-0002 already named this
  point as the revisit trigger.
- **A separate repository for backend bootstrap** — the standard pattern
  when a backend is shared across many consuming repos (one bootstrap,
  many consumers, decoupled lifecycles/permissions). Rejected here because
  nothing else uses this backend today; a second repo would mean a second
  set of CI/auth wiring for no present benefit. Revisit (split it out) if
  another repo ever needs to store state in the same bucket — at that
  point the shared infrastructure genuinely outlives any one consumer and
  deserves its own lifecycle.
- **Native S3 locking (`use_lockfile`, no DynamoDB)** — simpler (one fewer
  resource type), but requires Terraform ≥ 1.10; this repo pins `1.9.8`
  (`TF_VERSION` in both workflows). Rejected to avoid bundling an
  unrelated version bump into this change. Worth revisiting once the
  pinned version moves past 1.10 — see the tripwire in Consequences.
- **One shared IAM role for plan and apply** — simpler to wire up, but
  quietly drops the read-path-is-safe-by-construction property ADR-0002
  established. Rejected.
- **Static AWS access keys as a repo secret** — the "just get it working"
  option. Rejected as a straightforward regression from ADR-0001's
  reasoning against long-lived credentials.

## Consequences

- **Bootstrap is a manual, out-of-band step.** Nothing in CI ever creates
  or modifies the bucket/table/IAM roles — see `bootstrap/README.md`.
  Changing the bucket's lifecycle policy, rotating a role, or widening a
  trust condition all require someone to run `bootstrap/` by hand with
  their own AWS credentials.
- **If a second repo ever needs to store state in this same bucket**,
  reopen this ADR: that's the signal to split `bootstrap/` into its own
  repository (see Alternatives considered) rather than letting an
  increasingly shared, multi-consumer resource keep living inside one
  consumer's repo.
- **If `TF_VERSION` in the workflows is ever bumped to ≥ 1.10**, it's worth
  revisiting whether to drop the DynamoDB table for native S3 locking
  (`use_lockfile`) — simpler, one fewer resource to manage in `bootstrap/`.
  Not done now solely to avoid bundling that version bump into this
  change.
- **The plan/apply role split must be preserved** if CI is ever reworked —
  collapsing back to one role silently reintroduces the risk ADR-0002 and
  this ADR both went out of their way to avoid.
- **Durability is now native** (S3 versioning) instead of the
  before/after-apply artifact uploads ADR-0002 relied on as a manual
  mitigation for cache eviction — those artifact-upload steps are removed
  from `terraform-apply.yml`.
- Required repo Variables (`Settings → Secrets and variables → Actions`):
  `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_DYNAMODB_TABLE`,
  `TF_AWS_PLAN_ROLE_ARN`, `TF_AWS_APPLY_ROLE_ARN` — see README.md#state.
