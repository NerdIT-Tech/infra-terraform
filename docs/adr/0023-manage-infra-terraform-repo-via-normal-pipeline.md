# ADR-0023: Manage infra-terraform's own repo via the normal pipeline, not a bootstrap

**Status:** Accepted
**Date:** 2026-08-16

## Context

Every repo `NerdIT-Tech` manages gets one `modules/github-repository` block
in `repositories.tf` (ADR-0009) -- except `infra-terraform` itself. Its
repo settings were left to a manual runbook step (README's old "One-time
repo setup for CI"), on the assumption this repo has the same
chicken-and-egg problem `bootstrap/` exists for on the AWS side: CI can't
create the credentials it needs to run itself (ADR-0019).

That assumption doesn't hold on the GitHub side. The GitHub App this repo
authenticates as (ADR-0001) already has Administration/Contents write
access to `infra-terraform` from its one-time install -- independent of
anything Terraform has created. Nothing about applying a
`github_repository`/`github_branch_protection` change to this repo depends
on a resource this repo's own Terraform would need to create first, the
way an AWS IAM role does.

Left unmanaged, the standards this repo enforces on every other repo
drifted on itself: branch protection was never actually turned on (a
disabled ruleset from initial repo setup, not the classic protection API
the module manages), `allow_rebase_merge` was still `true` despite
ADR-0008's squash-only decision, and no `topics` were set despite
ADR-0014. The repo that defines the org's standards wasn't following them.

## Decision

Manage `infra-terraform`'s own repo settings the same way as every other
repo: one `module "infra_terraform"` block in `repositories.tf`, applied
through the normal PR + plan-gated CI pipeline (ADR-0003) -- not a
hand-applied bootstrap. Since the repo already exists, its first apply
adopts the live resource via a declarative `import {}` block (`imports.tf`,
same technique `bootstrap/README.md` documents for migrating `gitops`'s
AWS role pair), rather than trying to create a repo GitHub would reject as
already taken.

To cover the one real self-referential risk this does introduce --
`repositories.tf` losing this module block (bad refactor, mis-resolved
merge conflict) planning to delete the very repo the plan is running in --
`modules/github-repository/main.tf`'s `github_repository.this` resource
now carries `lifecycle { prevent_destroy = true }`. This applies to every
repo the module manages, not just `infra-terraform`: an accidental
Terraform-initiated repo deletion is catastrophic (issues, PRs, wiki, CI
history) for any managed repo, and this makes it require a deliberate,
separately-reviewed step (removing the `prevent_destroy` line, then
applying) instead of a single unnoticed plan.

## Alternatives considered

- **Extend `bootstrap/` with a `github` provider and a hand-applied module
  call for `infra-terraform`'s own repo**, mirroring the AWS role pair
  literally. Rejected: `bootstrap/`'s hand-applied nature exists
  specifically to solve AWS's credential chicken-and-egg (ADR-0019); there
  is no equivalent constraint here, so doing this anyway would add a
  permanently-manual step, and a second Terraform config with its own
  state, for no safety benefit over the normal pipeline.
- **Leave repo settings managed by hand**, as before. Rejected: this is the
  status quo that produced the drift described above -- exactly the
  problem ADR-0009 already solved for every other repo.
- **Manage it via the normal pipeline with no destroy guard.** Rejected: a
  plan that would destroy the repo running the pipeline that applies it is
  a materially different risk than destroying any other managed repo (it
  can take down the very automation applying the change mid-run), and
  `prevent_destroy` is a cheap, general guard against it.

## Consequences

- `infra-terraform`'s branch protection, merge settings, and topics are now
  enforced by the same `terraform plan`/`apply` cycle as every other repo
  -- a PR changing `required_status_checks` or merge settings for this repo
  shows up as an ordinary reviewed plan, not a silent GitHub UI edit.
- `imports.tf` should be deleted once a `terraform plan` after the import
  comes back clean (0 to add/change/destroy) -- it's a one-time adoption
  step, not permanent config (see `bootstrap/README.md`'s identical
  cleanup step for `gitops`).
- Deleting *any* repo the `github-repository` module manages now requires
  removing `prevent_destroy` in its own reviewed PR before a destroy plan
  will even generate -- a deliberate two-step process, not a one-shot
  accident. Worth knowing before proposing a repo's removal.
- `required_approving_review_count = 0` for `infra-terraform` reflects it
  being solo-maintained today (the same pattern `tplink-omada-sdk-for-go`
  already uses) -- raise it in the same PR that adds a second maintainer.
- The GitHub UI already has a disabled ruleset named `main`
  (`NerdIT-Tech/infra-terraform` ruleset ID 19184025) from before this
  change, left over from partial manual setup. It doesn't conflict with
  the classic `github_branch_protection` resource this module creates (a
  different GitHub API), but it's dead config now that real protection is
  Terraform-managed -- worth deleting by hand, not something this
  Terraform manages or will ever touch.
