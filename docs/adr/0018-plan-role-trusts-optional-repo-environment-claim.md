# ADR-0018: Plan role trust accepts an optional per-repo `environment:` claim

**Status:** Accepted
**Date:** 2026-08-01

## Context

[Issue #42](https://github.com/NerdIT-Tech/infra-terraform/issues/42):
`gitops`'s `terraform-pr.yml` `plan` job needs to declare `environment:
homelab` to reach Proxmox connection secrets/vars (`PROXMOX_ENDPOINT`,
`PROXMOX_NODE`, `SSH_PUBLIC_KEY`, `PROXMOX_API_TOKEN`) that live in that
GitHub Actions environment, not as plain repo secrets.

Declaring `environment:` on a job replaces the OIDC subject claim's shape
-- `pull_request`/`ref:refs/heads/...` becomes `environment:<name>`, it
doesn't add to it. This is the exact mechanism ADR-0012 already documents,
there for the `apply` job's `production` environment; here it's the `plan`
job, for an unrelated reason (secret scoping, not production gating).
`gitops-plan`'s trust policy (ADR-0017) only matched the `pull_request`/
`ref` patterns, so the actual token (confirmed via CloudTrail:
`repo:NerdIT-Tech@194043185/gitops@1317707257:environment:homelab`) matched
neither, and `sts:AssumeRoleWithWebIdentity` was denied.

## Decision

`var.repositories`' object type gains an optional `environment` field. When
set for a repo, `plan_trust`'s `sub` `StringLike` `values` for that repo
gain a third pattern, `"repo:${var.github_owner}@*/${each.key}@*:environment:${cfg.environment}"`,
*alongside* (not instead of) the existing `pull_request`/`ref` patterns --
because a repo's plan job might run other jobs/triggers that don't declare
the environment (a `StringLike` condition with multiple values is an OR).
`gitops` sets `environment = "homelab"`; `infra-terraform` leaves it unset,
since its own plan job deliberately never declares an environment
(ADR-0012).

`apply_trust` is untouched: every repo's apply role already unconditionally
matches `environment:production` (ADR-0012), which is orthogonal to this.

## Alternatives considered

- **Move the Proxmox secrets/vars to plain repo-level Actions
  secrets/variables**, so `gitops`'s plan job never needs to declare
  `environment:` and its OIDC subject stays in the shape `gitops-plan`
  already trusted -- no `infra-terraform` change at all. The issue raised
  this explicitly as a real option. Rejected (implicitly, by picking the
  trust-policy fix): the environment-scoping of those secrets was
  presumably intentional (separating homelab/Proxmox credentials from the
  repo's other secrets), and this repo's job is to make the trust policy
  match what a repo's CI actually needs to do, not to dictate how another
  repo organizes its own secrets.
- **Blanket-add an environment pattern to every repo's plan_trust**, using
  a single shared environment name -- simpler (`type = string`, not
  `optional(string)`) but wrong: it would grant every repo's plan role an
  environment-claim path whether or not that repo's plan job ever declares
  one, and different repos legitimately want different environment names
  (or none). Rejected in favor of the per-repo optional field.

## Consequences

- Adding a repo whose plan job needs `environment:` scoping is "set
  `environment = "<name>"` in its `var.repositories` entry" -- the matching
  trust pattern is generated automatically, same as ADR-0017's `state_keys`
  handling.
- If a repo's plan job's declared environment name ever changes, this
  variable must be updated to match, or plan runs start failing the same
  way issue #42 did -- there's no way to detect that mismatch from
  `bootstrap/` alone, since GitHub Actions environment names live in the
  other repo.
- Changing this requires re-applying `bootstrap/` by hand (see
  `bootstrap/README.md`), same as any other trust change (ADR-0013).
