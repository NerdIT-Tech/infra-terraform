# ADR-0016: Per-repo OIDC trust and state isolation, not a shared role pair

**Status:** Accepted -- supersedes 0015
**Date:** 2026-08-01

## Context

[ADR-0015](0015-multi-repo-oidc-trust-shared-state.md) let a second repo
(`gitops`) assume the existing `plan`/`apply` roles by widening their trust
policies' `sub` conditions to a list of repos, while both repos kept
sharing the one existing state object at `var.state_key`. It explicitly
flagged this as provisional: "revisit if a repo added to the list turns out
to need real isolation from the others."

`gitops` turned out to need exactly that: its own state under its own
`gitops/` key, not the same object `infra-terraform` uses. That surfaced a
sharper problem than "these two repos happen to want separate state." A
shared role's *IAM policy* is attached to the role, not to the caller --
whichever repo's OIDC token was used to assume it gets everything the
policy grants. Adding a second resource statement for `gitops/`'s key to
the existing shared `plan`/`apply` roles would not isolate anything: either
repo's CI could then read (or, for `apply`, write) *both* state objects,
because the trust policy's per-repo `sub` conditions only gate who can
assume the role, not what a given assumption is scoped to once assumed.

## Decision

`bootstrap/main.tf` creates one full `plan`/`apply` role pair **per entry**
in a new `var.repositories` map (`repo name => { state_key }`), using
`for_each` across the trust-policy documents, the IAM roles, and the
state-access policy documents:

- Each pair's trust policy's `sub` `StringLike` condition names exactly one
  repo (`each.key`) -- never a list.
- Each pair's IAM policy's resources are built from `local.repo_state[each.key]`,
  derived from that repo's own `state_key` -- never another repo's.
- Role names are derived as `"${each.key}-plan"` / `"${each.key}-apply"`,
  so the already-applied `infra-terraform-plan`/`infra-terraform-apply`
  roles keep their names; `moved` blocks in `bootstrap/moved.tf` carry their
  state addresses from the old single-resource form to
  `["infra-terraform"]` so this refactor needs no destroy/recreate.

Adding a repo is now "add a map entry" -- the trust policy, role, and
state-scoped IAM policy for it are generated, not hand-wired.

## Alternatives considered

- **Keep ADR-0015's shared roles, add `gitops/`'s key as a second resource
  statement** -- the option this ADR was originally reaching for. Rejected
  once it became clear it doesn't isolate anything (see Context): a
  compromised or merely misconfigured `gitops` PR could plan/apply
  `infra-terraform`'s own state, and vice versa, since the shared policy's
  resources aren't conditioned on which repo's token was used.
- **Session tags + resource conditions on the shared roles** -- have each
  repo's trust policy set a session tag (e.g. `aws:RequestTag/repo`) and
  condition every policy statement's resource grant on that tag, so one
  role pair could still legitimately scope access per caller. Rejected as
  meaningfully more complex to write and audit (tag wiring in the trust
  policy, matching conditions in every statement, for every future repo)
  than just generating a role pair per repo for the same result.

## Consequences

- `var.github_repository_names`, `var.plan_role_name`, `var.apply_role_name`,
  and `var.state_key` are gone, replaced by `var.repositories`. Any local
  `terraform.tfvars` overriding those needs updating to the map form.
- `outputs.tf` exposes one `role_arns` output: a map keyed by repo name,
  each entry holding `.plan`/`.apply`. This repo's own CI wiring reads
  `role_arns["infra-terraform"]`; any other repo (e.g. `gitops`) reads its
  own entry the same way -- one output shape for every repo, including this
  one, instead of a singular shortcut duplicating one map entry.
- Removing a repo from `var.repositories` destroys its role pair -- safe by
  construction, since no other repo's trust or policy ever referenced it.
- Two repos can still be pointed at the same `state_key` deliberately (nothing
  stops it), but doing so re-creates the ADR-0015 sharing problem for just
  those two -- `bootstrap/README.md`'s "Adding a repo" section calls this out.
