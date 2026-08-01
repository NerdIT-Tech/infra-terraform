# ADR-0018: Plan/apply role trust names each repo's environment gate, not a hardcoded "production"

**Status:** Accepted
**Date:** 2026-08-01

## Context

[Issue #42](https://github.com/NerdIT-Tech/infra-terraform/issues/42):
`gitops`'s `terraform-pr.yml` `plan` job needs to declare `environment:
homelab` to reach Proxmox connection secrets/vars (`PROXMOX_ENDPOINT`,
`PROXMOX_NODE`, `SSH_PUBLIC_KEY`, `PROXMOX_API_TOKEN`) that live in that
GitHub Actions environment, not as plain repo secrets. `gitops`'s `apply`
job is gated by that same `homelab` environment (a required-reviewer gate,
same purpose as `infra-terraform`'s `production` gate, just named for what
`gitops` actually deploys to) -- not a `production` one.

Declaring `environment:` on a job replaces the OIDC subject claim's shape
-- `pull_request`/`ref:refs/heads/...` becomes `environment:<name>`, it
doesn't add to it. This is the exact mechanism ADR-0012 already documents,
there for `infra-terraform`'s `apply` job and its `production` environment.
`gitops-plan`'s trust policy (ADR-0017) only matched the `pull_request`/
`ref` patterns, so the actual token (confirmed via CloudTrail:
`repo:NerdIT-Tech@194043185/gitops@1317707257:environment:homelab`) matched
neither, and `sts:AssumeRoleWithWebIdentity` was denied. `apply_trust` had
the same problem waiting to happen: it unconditionally matched only
`environment:production`, hardcoding an assumption -- that every repo's
apply gate is named "production" -- that was only ever true for
`infra-terraform`.

## Decision

`var.repositories`' object type gains two optional-ish fields:

- `plan_environment` (`optional(string)`, no default): set only if that
  repo's *plan* job itself declares `environment: <name>`. When set,
  `plan_trust`'s `sub` `StringLike` `values` for that repo gain a third
  pattern, `"repo:${var.github_owner}@*/${each.key}@*:environment:${cfg.plan_environment}"`,
  *alongside* (not instead of) the existing `pull_request`/`ref` patterns
  -- a repo's plan job might run other triggers that don't declare the
  environment, and `StringLike` with multiple values is an OR.
- `apply_environment` (`optional(string, "production")`): the environment
  name `apply_trust` matches for that repo. Defaults to `"production"`,
  preserving today's behavior for every repo that doesn't override it.

`gitops` sets both to `"homelab"`. `infra-terraform` sets neither (leaves
`plan_environment` unset, keeps the `apply_environment` default).

## Alternatives considered

- **Move the Proxmox secrets/vars to plain repo-level Actions
  secrets/variables**, so `gitops`'s plan job never needs to declare
  `environment:` at all -- no `infra-terraform` change needed for the plan
  side. The issue raised this explicitly. Rejected: doesn't address the
  apply side (a required-reviewer gate has to be an environment, that part
  isn't optional), and the environment-scoping of those secrets was
  presumably intentional. This repo's job is to match what a repo's CI
  actually needs, not to dictate how another repo organizes its secrets or
  gates.
- **Blanket-add a `homelab` (or shared) environment pattern to every repo's
  plan/apply trust** -- simpler (plain `string`, not `optional`) but wrong:
  grants every repo's roles an environment-claim path whether or not that
  repo's jobs ever declare one, and different repos legitimately want
  different (or no) environment names. Rejected in favor of per-repo
  fields.
- **Keep `apply_trust` hardcoded to `"production"` for every repo,
  restrict `gitops` to only ever apply from a job named to match** --
  rejected as backwards: the trust policy should describe what a repo's CI
  actually does, not constrain a repo's CI design to fit a naming
  assumption baked into a different repo's bootstrap config.

## Consequences

- Adding a repo whose plan job needs `environment:` scoping is "set
  `plan_environment`"; adding a repo whose apply gate isn't named
  `"production"` is "set `apply_environment`" -- both generate the matching
  trust pattern automatically, same as ADR-0017's `state_keys` handling.
- If a repo's plan or apply job's declared environment name ever changes,
  the corresponding field here must be updated to match, or runs start
  failing the same way issue #42 did -- there's no way to detect that
  mismatch from `bootstrap/` alone, since GitHub Actions environment names
  live in the other repo.
- Changing this requires re-applying `bootstrap/` by hand (see
  `bootstrap/README.md`), same as any other trust change (ADR-0013).
