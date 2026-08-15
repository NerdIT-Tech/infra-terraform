# ADR-0021: Migrate `terraform-pr.yml`/`terraform-apply.yml`'s composite actions to NerdIT-Tech/.github

**Status:** Accepted
**Date:** 2026-08-15

## Context

[#58](https://github.com/NerdIT-Tech/infra-terraform/issues/58) is migrating
this repo's CI to shared workflows/actions hosted in `NerdIT-Tech/.github`.
The first pass (see the `feat(ci): #58 migrate PR title lint...` commit)
moved `conventional-commits.yml` to a shared reusable workflow and added
`yaml-lint.yml`/`actionlint.yml` as new thin callers, but deliberately left
`terraform-pr.yml` and `terraform-apply.yml` untouched: swapping the
plan/apply pipeline's action sources is a bigger, separate decision, given
how much of ADR-0010/0012/0013/0017-0020 is built around those exact steps
(state locking, OIDC role assumption, the plan/apply artifact handoff).

By the time this ADR was written, `NerdIT-Tech/.github` had grown versioned
composite-action equivalents of every local action `terraform-pr.yml` and
`terraform-apply.yml` call: `terraform-lint-scan`, `terraform-init-s3`,
`terraform-plan`, `terraform-release-lock`, and `resolve-pr`, each a direct
port of this repo's action of the same name (confirmed byte-for-byte
identical except `terraform-lint-scan`, which inlines its Trivy step via
`aquasecurity/trivy-action` directly instead of through this repo's now-
redundant local `trivy-scan` wrapper). Each is release-please-versioned with
a floating `<action>/v1` major tag to pin to, per
`NerdIT-Tech/.github/.github/actions/README.md`'s own convention — the same
approach `actions/checkout@v7`, `aws-actions/configure-aws-credentials@v6`,
etc. already use in this repo, just for a first-party action instead of a
third-party one.

## Decision

`terraform-pr.yml` and `terraform-apply.yml` now call
`NerdIT-Tech/.github/.github/actions/<name>@<name>/v1` instead of
`./.github/actions/<name>` for `terraform-lint-scan`, `terraform-init-s3`,
`terraform-plan`, and `terraform-release-lock`. `resolve-pr` is pinned to
the exact `resolve-pr/v1.0.0` tag instead, since `NerdIT-Tech/.github` has
not yet cut a floating `resolve-pr/v1` major tag (every other action already
has one) — switch it to `resolve-pr/v1` once that tag exists.

The local copies of these five actions, plus `terraform-fmt`,
`terraform-init`, `terraform-validate`, `tflint`, and `trivy-scan` (only
ever used *by* `terraform-lint-scan`, never called directly from a
workflow here), are deleted — nothing in this repo references them anymore.

`semantic-pull-request` is the one local composite action that **stays**:
`NerdIT-Tech/.github`'s `reusable-semantic-pr-title.yml` (a `workflow_call`
reusable *workflow*, not a composite action) references it via
`./.github/actions/semantic-pull-request`, and a reusable workflow's
`./`-relative references resolve against the **caller's** repo, not the
workflow's own — unlike a composite action's `./`-relative references,
which resolve against the action's own defining repo. That's why
`NerdIT-Tech/.github`'s own `terraform-init-s3`/`terraform-lint-scan` can
safely call their sibling actions (`./.github/actions/terraform-init`, etc.)
purely within `NerdIT-Tech/.github` with no copy needed here, while
`semantic-pull-request` has the opposite requirement.

## Alternatives considered

- **Pin every action to a commit SHA**, matching how the three reusable
  workflows (`reusable-semantic-pr-title.yml` etc.) are pinned. Rejected:
  that SHA-pinning was a fallback forced by those workflows having no
  release-please tags at all, not a general policy. These five actions do
  have real, independently-versioned tags — using them keeps
  `terraform-pr.yml`/`terraform-apply.yml` on the same "pin to a floating
  major tag" convention already used for every third-party action in this
  repo (`actions/checkout@v7` and friends), rather than introducing a third
  pinning style.
- **Keep the local copies and not migrate this pair of workflows at all** —
  the option implicitly chosen by the prior commit. Rejected now: the
  actions are confirmed byte-identical ports, `NerdIT-Tech/.github` has
  cut real version tags for them, and leaving `terraform-pr.yml`/
  `terraform-apply.yml` on local copies indefinitely means every future fix
  to shared logic (e.g. a `terraform-plan` bugfix) has to be manually
  re-applied here instead of landing once upstream and being picked up via
  the `v1` tag.
- **Delete `terraform-fmt`/`terraform-init`/`terraform-validate`/`tflint`
  but keep a local `terraform-lint-scan` that calls the *upstream* siblings
  by full path** — rejected as unnecessary: `terraform-lint-scan/v1` from
  `NerdIT-Tech/.github` already composes its own siblings correctly (see
  Decision above), so there's nothing left for a local wrapper to add.

## Consequences

- A future fix to any of `terraform-lint-scan`, `terraform-init-s3`,
  `terraform-plan`, or `terraform-release-lock`'s *behavior* now happens in
  `NerdIT-Tech/.github`, not here — this repo picks it up automatically the
  next time that action's `v1` tag moves (or never, if it's pinned to an
  exact version). Bugs in the shared action affect every repo using it, not
  just this one.
- `resolve-pr` needs a one-line follow-up (`resolve-pr/v1.0.0` →
  `resolve-pr/v1`) once `NerdIT-Tech/.github` cuts that action's first
  floating major tag — a deliberate, tracked gap, not an oversight.
- `.github/actions/` in this repo now holds exactly one action
  (`semantic-pull-request`), kept specifically because reusable *workflows*
  resolve `./`-relative paths against the caller while composite *actions*
  resolve them against their own repo. Anyone adding a new
  `NerdIT-Tech/.github` reusable workflow that itself references a local
  composite action needs to check which of these two resolution rules
  applies before assuming the action can be deleted from here.
- Trust in `NerdIT-Tech/.github` now extends to steps that assume this
  repo's OIDC-federated AWS roles (`terraform-init-s3`) and write/read this
  repo's Terraform state lock (`terraform-plan`, `terraform-release-lock`)
  — previously that logic only ever lived in this repo's own reviewed
  history. Pinning to major-version tags (not `main`) bounds this to
  changes that land through `NerdIT-Tech/.github`'s own release-please
  flow, same trust model this repo already extends to every third-party
  action it calls.
