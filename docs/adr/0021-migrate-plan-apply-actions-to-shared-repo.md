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

**First attempt got the `./`-resolution rule backwards.** The initial
version of this change deleted `terraform-fmt`, `terraform-init`,
`terraform-validate`, and `tflint` on the theory that a composite action's
internal `./`-relative `uses:` resolves against *that action's own defining
repo* — as opposed to a reusable `workflow_call` workflow's `./`-relative
references, which the prior PR had already established resolve against the
**caller's** checkout (that's why `semantic-pull-request` had to stay
local). That theory was wrong, and CI on this PR proved it: the `validate`
job failed with `Can't find 'action.yml' ... under
'/home/runner/work/infra-terraform/infra-terraform/.github/actions/terraform-fmt'`
— GitHub was resolving `NerdIT-Tech/.github`'s `terraform-lint-scan`
action's internal `uses: ./.github/actions/terraform-fmt` step against
*this* repo's checkout, exactly like it does for a reusable workflow.
**There is no difference between the two: every `./`-relative `uses:`,
whether in a workflow job, a reusable `workflow_call` workflow, or nested
inside a composite action, resolves against `GITHUB_WORKSPACE` — the
top-level caller's checkout.** A composite action pulled from another repo
never gets its own separate checkout to resolve `./` against.

## Decision

`terraform-pr.yml` and `terraform-apply.yml` now call
`NerdIT-Tech/.github/.github/actions/<name>@<name>/v1` instead of
`./.github/actions/<name>` for `terraform-lint-scan`, `terraform-init-s3`,
`terraform-plan`, and `terraform-release-lock`. `resolve-pr` is pinned to
the exact `resolve-pr/v1.0.0` tag instead, since `NerdIT-Tech/.github` has
not yet cut a floating `resolve-pr/v1` major tag (every other action already
has one) — switch it to `resolve-pr/v1` once that tag exists.

Only `trivy-scan` is deleted from the local action set — nothing calls it
anymore, since `NerdIT-Tech/.github`'s `terraform-lint-scan` inlines its
Trivy step directly rather than through a wrapper action.
`terraform-fmt`, `terraform-init`, `terraform-validate`, and `tflint`
**stay local**, alongside `semantic-pull-request`, for the reason established
above: `NerdIT-Tech/.github`'s `terraform-lint-scan` and `terraform-init-s3`
each reference these by `./.github/actions/<name>` internally, and that
resolves against *this* repo's checkout no matter which repo hosts
`terraform-lint-scan`/`terraform-init-s3` themselves. `terraform-plan`,
`terraform-release-lock`, and `resolve-pr` have no such nested local
references (checked directly against their `NerdIT-Tech/.github` source),
so those three don't need local copies of anything.

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
  and have a local `terraform-lint-scan`/`terraform-init-s3` reference the
  *upstream* siblings by full `NerdIT-Tech/.github` path instead of `./`** —
  would work (it sidesteps the resolution rule entirely), but requires
  forking/rewriting `terraform-lint-scan`/`terraform-init-s3` locally
  instead of calling `NerdIT-Tech/.github`'s versions directly, which
  defeats the point of this migration for exactly those two actions.
  Rejected in favor of just keeping the four small leaf actions they depend
  on local — a smaller, more honest reflection of what GitHub actually
  requires.

## Consequences

- A future fix to `terraform-lint-scan`, `terraform-init-s3` (their own
  top-level logic), `terraform-plan`, or `terraform-release-lock` happens in
  `NerdIT-Tech/.github`, not here, and this repo picks it up automatically
  the next time that action's `v1` tag moves. A fix to the *leaf* actions
  (`terraform-fmt`/`terraform-init`/`terraform-validate`/`tflint`) does
  **not** flow through automatically — this repo's local copies have to be
  manually kept in sync with `NerdIT-Tech/.github`'s (or, if `.github`
  changes the way `terraform-lint-scan`/`terraform-init-s3` reference their
  siblings, e.g. to an explicit `NerdIT-Tech/.github/...@ref` instead of
  `./`, revisit deleting these four entirely).
- `resolve-pr` needs a one-line follow-up (`resolve-pr/v1.0.0` →
  `resolve-pr/v1`) once `NerdIT-Tech/.github` cuts that action's first
  floating major tag — a deliberate, tracked gap, not an oversight.
- `.github/actions/` in this repo now holds five actions:
  `semantic-pull-request`, `terraform-fmt`, `terraform-init`,
  `terraform-validate`, `tflint` — all kept for the same reason (a
  `NerdIT-Tech/.github` workflow or composite action references them via a
  `./`-relative path, which always resolves against *this* repo's checkout,
  never against `NerdIT-Tech/.github`'s own). Before deleting any local
  action as "redundant now that it's in `.github`," grep
  `NerdIT-Tech/.github` for a `./.github/actions/<name>` reference to it —
  if one exists anywhere in the call chain a workflow here invokes, the
  local copy has to stay.
- Trust in `NerdIT-Tech/.github` now extends to steps that assume this
  repo's OIDC-federated AWS roles (`terraform-init-s3`) and write/read this
  repo's Terraform state lock (`terraform-plan`, `terraform-release-lock`)
  — previously that logic only ever lived in this repo's own reviewed
  history. Pinning to major-version tags (not `main`) bounds this to
  changes that land through `NerdIT-Tech/.github`'s own release-please
  flow, same trust model this repo already extends to every third-party
  action it calls.
