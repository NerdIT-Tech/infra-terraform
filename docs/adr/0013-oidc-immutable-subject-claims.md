# ADR-0013: Tolerate GitHub's immutable OIDC subject claims with `@*` wildcards

**Status:** Accepted
**Date:** 2026-07-26

## Context

After fixing [ADR-0012](0012-plan-jobs-drop-production-environment.md)'s
environment-scoping collision, `terraform-pr.yml`'s `plan` job still failed
to assume the `plan` role: `Not authorized to perform
sts:AssumeRoleWithWebIdentity`. The deployed role's trust policy, checked
directly in the AWS console, matched `bootstrap/main.tf`'s `plan_trust`
exactly, and the OIDC provider's registered audience (`sts.amazonaws.com`)
was correct too — so the mismatch had to be in the actual token claims.

A temporary debug step (fetching and decoding the real ID token's payload,
never the signed token) showed the actual `sub` claim:

```
repo:NerdIT-Tech@194043185/infra-terraform@1305370731:pull_request
```

Not the plain `repo:OWNER/REPO:pull_request` format GitHub's general OIDC
documentation describes. This org/repo has GitHub's **immutable subject
claims** behavior in effect, which embeds the org's and repo's stable
numeric database IDs into the `sub` claim (`OWNER@ID`, `REPO@ID`) so the
claim keeps working — and keeps meaning the same repository — across a
rename or ownership transfer. `plan_trust`'s `StringLike` conditions,
written for the plain format, could never match this.

## Decision

Both `plan_trust` and `apply_trust`'s subject conditions in
`bootstrap/main.tf` use `@*` immediately after the org name and after the
repo name:

```
"repo:${var.github_owner}@*/${var.github_repository_name}@*:pull_request"
```

`StringLike`'s `*` wildcard absorbs the `@<numeric-id>` suffix (or matches
nothing, if a future token ever omits it) without hardcoding the actual ID
values into the Terraform config.

## Alternatives considered

- **Hardcode the literal numeric IDs** (`NerdIT-Tech@194043185`,
  `infra-terraform@1305370731`) — these are the whole point of this claim
  format (immutable, won't change even across a rename), so hardcoding
  them isn't actually fragile. Rejected anyway in favor of the wildcard:
  it reads as "this org, this repo" without a reader having to know what
  the magic numbers mean or where they came from.
- **Disable immutable subject claims for this org/repo**, reverting to the
  plain `sub` format, so the original (pre-ADR-0013) trust conditions work
  unmodified — would have avoided touching `bootstrap/main.tf` at all.
  Rejected: that setting is an org/repo-level security posture decision
  (it exists specifically to prevent subject-claim reuse after a rename),
  not something to weaken just to sidestep updating two wildcard patterns.

## Consequences

- Any other IAM trust policy this org adds later for GitHub Actions OIDC
  (a new role, a new repo's bootstrap) needs the same `@*` treatment, or
  it will fail the same way this one did. This is the second time an OIDC
  subject-claim assumption written from general documentation didn't match
  this org's actual configuration (see also ADR-0012) — check the real
  token (e.g. the debug-step approach used here) before trusting docs-only
  assumptions about claim format anywhere in this org.
- Changing `bootstrap/main.tf`'s trust conditions requires re-applying
  `bootstrap/` by hand (see `bootstrap/README.md`) before it takes effect.
