# ADR-0016: Multiple repos share one OIDC trust and one state object

**Status:** Superseded by [ADR-0017](0017-per-repo-oidc-trust-and-state-isolation.md)
**Date:** 2026-07-31

## Context

`bootstrap/main.tf`'s `plan`/`apply` IAM roles were trusted by exactly one
repo (`infra-terraform`, via `var.github_repository_name`). Adding the
`gitops` repo (see `repositories.tf`) meant its CI also needed to assume
these roles, so the trust policies had to accept more than one repo.

## Decision

`var.github_repository_name` (string) became `var.github_repository_names`
(list(string), default `["infra-terraform", "gitops"]`). `plan_trust` and
`apply_trust`'s `sub` `StringLike` conditions now loop over the list,
generating one wildcarded (`@*`, per ADR-0013) subject pattern per repo.

Every repo in the list shares the *same* `plan`/`apply` roles, which still
read/write the single state object at `var.state_key` -- there is no
per-repo state isolation. Any repo added to the list gains the ability to
plan/apply that one shared state.

## Alternatives considered

- **Per-repo state isolation**: a `map(object({ state_key = string }))`
  variable, with each repo getting its own state object and its own scoped
  IAM policy statements (no cross-repo access). More correct for repos that
  manage genuinely separate infrastructure, but adds a resource-per-repo
  fan-out (roles, policies, `for_each`) for a want that, right now, is
  "let gitops's CI also reach this same backend" -- not "gitops needs its
  own isolated Terraform state." Rejected for now as more machinery than
  the actual need; revisit if a repo added to the list turns out to need
  real isolation from the others.
- **A separate bootstrap/role pair per repo**, applied independently --
  avoids shared trust entirely, but multiplies the one-time hand-applied
  setup in `bootstrap/README.md` per repo and defeats the point of a shared
  backend. Rejected.

## Consequences

- Adding a repo to `github_repository_names` is enough to let its CI
  assume `plan`/`apply` -- and therefore read (plan) or read/write (apply)
  the *same* shared state object every other listed repo uses. Before
  adding a repo here, confirm it's actually meant to share that state, not
  just "also needs some AWS OIDC role."
- Changing this list requires re-applying `bootstrap/` by hand (see
  `bootstrap/README.md`), same as any other trust change (ADR-0013).
