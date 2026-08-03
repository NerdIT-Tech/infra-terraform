# ADR-0019: Move per-repo CI IAM role generation out of bootstrap/, into the main repo

**Status:** Accepted — supersedes 0010, amends 0017
**Date:** 2026-08-02

## Context

`bootstrap/main.tf` has grown to mix two different kinds of logic under one
"bootstrap" label:

1. **Irreducibly one-time infra** — the S3 state bucket (versioning, SSE,
   public-access block, bucket policy) and the GitHub Actions OIDC
   provider. These must exist before *any* CI role can authenticate to AWS
   at all, so they can never be created by the CI they're a prerequisite
   for (the chicken-and-egg problem ADR-0010 already named).
2. **Per-repo IAM role pairs** (`aws_iam_role.plan`/`.apply`, one pair per
   entry in `var.repositories`, per ADR-0017) — this recurs every time a
   Terraform-consuming repo is added. Today that's `infra-terraform` and
   `gitops`. Unlike (1), most of this has no chicken-and-egg problem: once
   `infra-terraform`'s own role pair exists, `infra-terraform`'s own CI has
   everything it needs to create a *different* repo's role pair. But
   ADR-0010 put all of it in `bootstrap/`, which is applied by hand, never
   by CI — so adding `gitops` (or any future repo) to `var.repositories`
   requires someone to run `terraform apply` against `bootstrap/` with
   their own AWS credentials, entirely outside the reviewed, plan-gated
   pipeline (ADR-0003) every other change in this org goes through.

`infra-terraform`'s own role pair is the one entry in `var.repositories`
that genuinely can't move: CI can't create the credentials it needs to run
itself. Every other repo's pair can move into the main repo instead —
the same `for_each`-over-a-map logic `bootstrap/main.tf` already had,
pulled directly into the main repo and applied through the normal pipeline
like everything else this repo manages — closing the gap ADR-0017 left
("adding a repo is now add a map entry [to bootstrap]") one step further,
to "add a map entry and let CI apply it."

This was confirmed with the user before implementing: the full move (roles,
trust policies, *and* state-access policies, not just deduplicating the
repo list between `bootstrap/` and the main config) was the explicit
choice, accepting that it requires granting `infra-terraform`'s own `apply`
role scoped IAM-management permissions it didn't have before.

## Decision

- `bootstrap/` keeps only: the S3 bucket and its supporting resources, the
  GitHub OIDC provider, and `infra-terraform`'s own `plan`/`apply` role
  pair + state-access policies (`var.repositories` in `bootstrap/` shrinks
  to exactly `{ "infra-terraform" = {...} }`). Still applied by hand, never
  by CI.
- `infra-terraform`'s `apply` role gains one new inline IAM policy, created
  in `bootstrap/main.tf`, granting exactly the actions needed to
  create/update/delete another repo's role pair (`iam:CreateRole`,
  `iam:DeleteRole`, `iam:GetRole`, `iam:TagRole`, `iam:UntagRole`,
  `iam:UpdateAssumeRolePolicy`, `iam:PutRolePolicy`, `iam:GetRolePolicy`,
  `iam:ListRolePolicies`, `iam:ListAttachedRolePolicies`,
  `iam:DeleteRolePolicy`), scoped by resource ARN to role names matching
  `*-plan`/`*-apply`, with an explicit `Deny` statement carving out
  `infra-terraform-plan`/`infra-terraform-apply` specifically —
  `infra-terraform`'s own CI can create or modify *other* repos' roles, but
  can never touch its own, i.e. it can never grant itself more power than
  `bootstrap/` gave it by hand.
- `infra-terraform`'s `plan` role gains the read-only half of that same
  access (`iam:GetRole`, `iam:GetRolePolicy`, `iam:ListRolePolicies`,
  `iam:ListAttachedRolePolicies` -- the latter two easy to miss, since
  they're what `aws_iam_role`'s own refresh calls to enumerate a role's
  inline and managed-policy attachments respectively, separately from
  `GetRolePolicy`'s per-policy read, and separately from each other --
  same `*-plan`/`*-apply` scoping, no `Deny` needed since reads carry no
  privilege-escalation risk) — every `terraform plan` refreshes each
  managed resource's real state before showing a diff, not just
  `terraform apply`, so the read-only role needs this permanently, not
  only for the one-time
  `gitops` import.
- `ci-roles.tf` resolves the OIDC provider's and state bucket's ARNs by
  string construction (`data.aws_caller_identity` + the fixed, known-in-
  advance ARN shape for each), not a `data "aws_iam_openid_connect_provider"`/
  `data "aws_s3_bucket"` lookup — both are fully deterministic from inputs
  already in hand, so resolving them declaratively would otherwise need
  its own IAM read grant (`iam:ListOpenIDConnectProviders`/
  `GetOpenIDConnectProvider`, `s3:GetBucketLocation`) on the `plan` role
  for no benefit over just computing the string.
- Every other repo's role pair — today just `gitops` — is generated in a
  new root `ci-roles.tf`, using the same `for_each = var.ci_repositories`
  shape `bootstrap/main.tf` used before this ADR (trust policy documents,
  `aws_iam_role.plan`/`.apply`, state-access policy documents), pulled
  across largely as-is rather than re-abstracted into a module — with only
  one consumer (`gitops`) today, a module would be an abstraction with no
  second use case yet to validate its shape against. Adding a repo's AWS CI
  access is now a normal reviewed PR against the main repo, plan-gated per
  ADR-0003, not a hand-run `bootstrap/` apply.

## Alternatives considered

- **Move `infra-terraform`'s own role pair too (fully self-managing)** —
  the main repo's CI would create and maintain every role including its
  own. Rejected: still circular for the very first apply (nothing exists
  yet to run that Terraform under), and it deletes a safety property worth
  keeping deliberately — that `infra-terraform`'s CI can never widen its
  own permissions. Keeping exactly one exception in `bootstrap/` is a small
  price for that guarantee.
- **Leave everything in `bootstrap/`, just deduplicate the repo list**
  (e.g. have `bootstrap/` read `repositories.tf`'s module names instead of
  maintaining its own `var.repositories`) — this was explicitly offered to
  and passed over by the user. It removes some drift risk but does nothing
  for the actual friction (a hand-run apply for every new repo) and leaves
  ADR-0010's "nothing in CI ever creates or modifies IAM roles" intact,
  which no longer reflects what's needed here.
- **Session tags + resource conditions on the shared roles** — ADR-0017
  already rejected this shape once for the same reason: more moving parts
  to audit than a role pair per repo, for the same outcome.
- **A dedicated `modules/terraform-ci-role/` module**, one call per repo
  (matching ADR-0009's "one module call per managed thing" convention) —
  tried first, then deliberately backed out. With exactly one consumer
  (`gitops`), the module's variable surface was a guess at what a second
  repo would need, not something validated by a second real use case; the
  inline `for_each` form is also a more direct, smaller diff from
  `bootstrap/main.tf`'s original code, which matters for reviewing a
  security-sensitive change like this one. Revisit if a third
  Terraform-consuming repo makes the per-repo block noticeably repetitive —
  ADR-0009's own reasoning (a fix has to be hand-applied to every copy
  instead of landing once) starts to bite once there's real duplication to
  point at.

## Consequences

- Adding a new Terraform-consuming repo: add an entry to
  `var.ci_repositories` (main repo), same PR/review/plan-gate flow as any
  other change — no more hand-run `bootstrap/` apply, no more AWS
  credentials needed outside the CI roles themselves.
- `infra-terraform`'s own role pair remains the one permanent exception,
  created and only ever changed by hand in `bootstrap/` — this is not
  expected to change again; if it ever needs to (e.g. to also self-manage),
  reopen this ADR rather than quietly special-casing it.
- The `Deny`-self-modification statement on `infra-terraform-apply`'s new
  IAM-management policy is a security invariant, not incidental: any future
  change to that policy must preserve it, or a compromised/misconfigured
  `infra-terraform` PR could grant its own CI role arbitrary new
  permissions via Terraform itself.
- The `*-plan`/`*-apply` resource-name pattern is a soft convention, not an
  AWS-enforced boundary: a future repo literally named so its role would be
  `infra-terraform-plan`/`infra-terraform-apply` (it can't — those names
  are taken — but a rename or similarly-colliding name elsewhere is
  conceivable) needs a second look at the `Deny` statement's resource list
  before being onboarded.
- **Migrating `gitops`'s already-live role pair is a one-time, cross-state
  operation** — `moved {}` blocks only work within one state, not across
  two separate root configs' backends. The import half is declarative: the
  main repo's `imports.tf` uses `import {}` blocks, applied through the
  normal PR + plan-gated pipeline, no manual AWS credentials needed. The
  removal half is still a hand-run `terraform state rm` in `bootstrap/` --
  Terraform's `removed {}` block was tried and rejected here (confirmed
  against this repo's pinned Terraform release, not assumed): it only
  accepts a whole resource address, not one instance of a `for_each`
  resource, and `bootstrap/`'s `aws_iam_role.plan`/`.apply` still have a
  live `"infra-terraform"` instance that must keep being managed, so there
  is no declarative way to drop only the `"gitops"` key. See
  `bootstrap/README.md` for the exact order. Not automated end-to-end and
  not expected to recur once `gitops` is migrated; every repo onboarded
  *after* this ADR is created fresh in the main repo and never needs
  either mechanism.
- This supersedes ADR-0010's consequence that "nothing in CI ever creates
  or modifies the bucket/IAM roles" — that remains true for the bucket and
  for `infra-terraform`'s own role pair, but no longer for other repos'
  role pairs. It amends ADR-0017: the `for_each`-over-a-map mechanism it
  introduced is unchanged in shape, just split across two configs — the
  main repo's `ci-roles.tf` runs it over `var.ci_repositories` (every repo
  except `infra-terraform`), and `bootstrap/main.tf` keeps running it over
  its own `var.repositories`, now a singleton (`infra-terraform` only).
