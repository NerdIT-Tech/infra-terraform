# ADR-0001: Authenticate to GitHub as a GitHub App, not a personal access token

**Status:** Accepted
**Date:** 2026-07-19 (retroactively documented; predates this ADR log)

## Context

Terraform needs credentials to manage GitHub-side resources (repositories,
branch protection, and eventually org membership/teams) via the `github`
provider. The obvious default is a personal access token (PAT) belonging to
whoever sets up CI.

## Decision

Authenticate as a **GitHub App** installed on the `NerdIT-Tech` org, using
`GITHUB_APP_ID` / `GITHUB_APP_INSTALLATION_ID` / `GITHUB_APP_PEM_FILE` read
from the environment. `providers.tf` deliberately has no `app_auth` block —
credentials never appear in `.tf`, `.tfvars`, or state.

The App's repository permissions are scoped narrowly to what Terraform
actually needs today: **Administration** (read/write — create/configure
repos), **Contents** (read/write — branch protection, initial commit), and
**Metadata** (read-only baseline). More scopes get added only when a new
resource type requires them (e.g. org-level **Members** for teams).

## Alternatives considered

- **Personal access token** — simplest to set up, but scoped to whoever
  generated it. If that person leaves the org or their token is revoked,
  CI breaks, and the access is tied to an individual's account rather than
  the org.
- **Fine-grained PAT owned by a bot/service account** — narrower than a
  classic PAT, but still a token belonging to *some* account (real or
  machine) that has to be provisioned, rotated, and kept alive.

A GitHub App sidesteps both: it's an org-level identity that isn't attached
to any one person's account, and its permissions are explicit and scoped
per-repository rather than inherited from whoever owns the token.

## Consequences

- Setup has an extra one-time step (create the App, install it, wire up
  its ID/installation ID/private key) — see README.md's "Authentication"
  section for the exact steps.
- The private key (`.pem`) must be kept out of git entirely (`.gitignore`
  already excludes `*.pem`) and is stored **base64-encoded** in the
  `TF_GITHUB_APP_PEM` Actions secret — pasting the raw multi-line PEM
  directly causes newline-mangling errors from the GitHub API ("no
  decodeable PEM data found"). Base64 sidesteps that.
- Adding a new managed asset type (e.g. teams) means widening the App's
  permissions on the GitHub side, not just adding Terraform config — the
  two have to be kept in sync manually since the App's grants aren't
  themselves managed by this Terraform.
