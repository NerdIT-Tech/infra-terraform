# ADR-0020: Modularize per-repo CI IAM role generation into `modules/aws/tf-iams`

**Status:** Accepted — amends 0019
**Date:** 2026-08-03

## Context

[ADR-0019](0019-move-per-repo-ci-roles-out-of-bootstrap.md) considered and
deliberately backed out a dedicated module for `ci-roles.tf`'s per-repo
plan/apply role pair, on two grounds: `gitops` was (and, as of this ADR,
still is) the *only* consumer, so the module's variable surface would be a
guess rather than something validated by a second real use case; and the
inline `for_each` form kept the diff against `bootstrap/main.tf`'s original
code small, which mattered for reviewing a security-sensitive change. It
named its own revisit trigger explicitly: "a third Terraform-consuming repo
[making] the per-repo block noticeably repetitive."

That repo-count trigger hasn't fired. What changed instead is the shape of
what a repo needs to express. ADR-0017/ADR-0018 already needed
`state_keys`, `plan_environment`, and `apply_environment` per repo. This
ADR adds three more independent axes on top of those: which branches are
trusted for plan (`plan_refs`) and, opt-in, for apply (`apply_refs`); and
which specific workflow files are trusted (`plan_workflows`/
`apply_workflows`, matched against the OIDC `job_workflow_ref` claim,
separate from the `sub` claim `plan_environment`/`apply_environment`
already use). Six independent, optional, per-repo dimensions is exactly the
kind of variable surface ADR-0019 said a single consumer couldn't validate
— but letting it keep growing as a copy-pasted inline block, rather than a
named, independently testable unit, is the more concrete risk now: six
interacting optional fields inside one shared `for_each` block is harder to
review correctly than the same six fields as one module's documented
interface, regardless of how many repos currently call it.

`modules/aws/tf-iams/` already existed as an empty directory on this
branch before this change — this ADR is what fills it in.

## Decision

`ci-roles.tf`'s `plan_trust`/`apply_trust`/`aws_iam_role.plan`/`.apply`/
`plan_state_access`/`apply_state_access` move into `modules/aws/tf-iams/`,
one `module` call per `var.ci_repositories` entry (`for_each`, same as
before — the map-of-repos shape ADR-0017 introduced is unchanged, only
where the body underneath it lives). The module takes `repo_name`,
`github_owner`, `oidc_provider_arn`, `state_bucket_arn`, `state_keys`, and
the six new selection inputs.

- `plan_refs` (`list(string)`, default `["main"]`): branch names trusted for
  plan via a ref-based `sub` claim pattern, alongside the always-trusted
  `pull_request` pattern and any `plan_environment`. Default preserves
  ADR-0019's hardcoded `ref:refs/heads/main`.
- `apply_refs` (`list(string)`, default `[]`): branch names *additionally*
  trusted for apply via a ref-based `sub` claim. Empty by default —
  apply trust stays environment-only, preserving
  [ADR-0003](0003-plan-gated-apply-pipeline.md)'s required-reviewer gate.
  **Setting this is a real weakening**, not a convenience knob: any branch
  listed can assume the read-write apply role from a push-triggered job
  that never declares `environment:`, with no reviewer gate in the path at
  all. It exists because the user asked for configurable ref selection on
  both plan and apply, not because a repo needs it today — no
  `var.ci_repositories` entry sets it.
- `plan_workflows`/`apply_workflows` (`list(string)`, default `[]`):
  workflow file names (e.g. `"terraform-pr.yml"`) matched against the OIDC
  `job_workflow_ref` claim via a second, ANDed `condition` block — narrower
  than the `sub` claim alone, since `sub` doesn't encode which workflow file
  triggered the run at all.

## Alternatives considered

- **Keep the inline `for_each` block, just add the six new fields to it** —
  what ADR-0019 chose for the original, smaller field set. Rejected now:
  the review cost ADR-0019 was optimizing for (a small diff, easy to audit
  for the specific IAM permissions it grants) inverts once the field count
  triples — six optional, interacting fields in one undifferentiated block
  is harder to reason about *per field* than the same six fields as one
  module's named, independently-documented inputs.
- **Wait for a third repo**, per ADR-0019's own stated trigger, and hold off
  on both the module and the new selection fields. Rejected: the user
  explicitly asked for this now; ADR-0019's trigger was written for the
  original, smaller field set and didn't anticipate this axis of growth.
- **Restrict `apply_refs` to module-internal use only (no way to actually
  set it from `var.ci_repositories`)**, so the risky knob exists in the
  module's interface but can't actually be reached. Rejected as
  half-finished — either a repo can express "trust this branch for apply"
  or it can't; hiding the field instead of documenting its risk doesn't
  make it safer, just less discoverable.

## Consequences

- Adding a repo to `var.ci_repositories` with only `state_keys` set (the
  common case) behaves identically to before this ADR: `plan_refs`
  defaults to `["main"]`, everything else defaults to empty/`"production"`.
  No existing behavior changes for `gitops` — the one deployed consumer's
  config didn't need to change.
- `apply_refs` is a loaded footgun by design — see its warning above and in
  `modules/aws/tf-iams/variables.tf`. Anyone reviewing a PR that sets it
  for the first time should treat it the same as reviewing a change to
  `bootstrap/main.tf`'s IAM-management `Deny` statement (ADR-0019's own
  security invariant): read it as "this repo's apply path no longer
  requires a human reviewer," not as an ordinary config tweak.
- `plan_workflows`/`apply_workflows`' `job_workflow_ref` matching has
  **not** been verified against a real decoded token for this org's
  immutable-subject-claims configuration, unlike the `sub` claim's `@*`
  treatment, which ADR-0013 root-caused against an actual token before
  committing to it. The first repo that sets either field should verify
  the claim's real shape the same way (decode the actual token in a
  debug step) before trusting it to deny or admit correctly — see
  ADR-0013's own consequence, which already flagged this exact class of
  mistake as likely to recur.
- `moved.tf` (root) carries `gitops`'s already-applied role pair's state
  address from the pre-ADR-0020 root resources into the new module path;
  `imports.tf`'s `to` addresses were updated to the module path directly.
  Both are safe regardless of whether `gitops`'s ADR-0019 import had
  already completed when this merges.
- This amends, not supersedes, ADR-0019: the decision to generate every
  non-`infra-terraform` repo's role pair in the main repo, through the
  normal plan-gated pipeline, is unchanged — only the internal shape
  (module vs. inline `for_each`) moved. If a fourth independent selection
  axis shows up later, re-read this ADR's Alternatives before reaching for
  a seventh field on the same module rather than reconsidering its
  interface.
