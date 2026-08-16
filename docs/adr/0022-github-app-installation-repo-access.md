# ADR-0022: Manage GitHub App installation repository access, not App creation

**Status:** Accepted
**Date:** 2026-08-16

## Context

This repo already authenticates to GitHub as an App (ADR-0001), and that
App's own repository access is granted by hand during its one-time install.
As more Apps get installed on `NerdIT-Tech` (CI bots, scanners, etc.),
granting each one access to a new repo has been a manual step in the GitHub
UI — the same problem `repositories.tf` solved for repository settings
themselves (ADR-0009).

GitHub's API doesn't offer a way to create a GitHub App declaratively: App
registration only happens through the interactive manifest flow (a browser
redirect to github.com that hands back a one-time code) or by hand in the
web UI. The `integrations/github` Terraform provider has no `github_app`
create resource, and can't have one without that API existing. It does,
however, expose two resources for managing an *already-installed* App's
repository scope:

- `github_app_installation_repository` (singular) — additive: grants one
  repo to an installation without touching any others already granted.
- `github_app_installation_repositories` (plural) — authoritative: takes
  the installation's complete desired repository set and prunes anything
  not listed, including repos added outside Terraform.

## Decision

`modules/github-app-installation/` wraps the plural,
`github_app_installation_repositories` resource. Terraform owns the
installation's full repository list once a module block exists for it, the
same way `github_repository` owns a repo's settings — additions made by
hand in the GitHub UI are drift, not a coexisting source of truth.

Creating the App itself stays a documented manual runbook step (README's
"Adding a managed App installation"), not a Terraform resource. This
repo's own Terraform App (ADR-0001) already gets this same manual
treatment for its own creation; installed Apps this repo manages get it
too, and only their repository *access* becomes declarative.

## Alternatives considered

- **The singular `github_app_installation_repository` resource** — lets
  Terraform-managed and manually-added repos coexist without either
  fighting the other. Rejected: it means the module block is never a
  complete picture of an installation's access, which is exactly the kind
  of partial ownership this repo has avoided elsewhere (e.g. ADR-0009
  chose one module call per repo over hand-written resource blocks
  precisely so a module block is the full story).
- **Script the manifest flow to automate App creation too** — would close
  the remaining manual gap, but requires a local HTTP server to receive
  the flow's redirect and isn't something Terraform (or `terraform apply`
  running in CI) can do. Left as a possible separate effort, not bundled
  into this decision.

## Consequences

- Adding a managed installation means two steps that must both happen:
  create/install the App by hand (App ID and Installation ID come out of
  that), then add a `modules/github-app-installation` block with the
  Installation ID and the full repository list. The module has nothing to
  manage until the manual half is done first.
- Because the plural resource is authoritative, whoever installs a new App
  should pick **Only select repositories** (not "All repositories") during
  install — Terraform will otherwise fight the installation's default
  scope on the first apply.
- The Terraform App itself may need a wider permission grant (likely
  **Organization administration**) to call this API for *other* Apps'
  installations — unconfirmed until actually exercised; see the TODO in
  README.md's Authentication section. Same manual-sync obligation ADR-0001
  already noted: the App's permissions aren't themselves managed by this
  Terraform, so widening them is a separate GitHub-side step.
