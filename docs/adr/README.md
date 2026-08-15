# Architecture Decision Records

Each file here records one deliberate architectural or process trade-off in
this repo: what was decided, what alternatives were rejected, and what it
obligates future changes to respect. This is the authoritative home for
"why" in this repo — `README.md` covers "what" and "how to run it."

Start a new ADR from `template.md` when a real trade-off gets decided (not
for routine bug fixes or anything already fully explained by a commit
message). Prefer a new ADR that supersedes/amends an old one over editing
history — see ADR-0004 for an example of amending ADR-0003.

| # | Title | Status |
|---|-------|--------|
| [0001](0001-github-app-auth.md) | Authenticate to GitHub as a GitHub App, not a PAT | Accepted |
| [0002](0002-local-state-via-actions-cache.md) | Persist Terraform state via the Actions cache, not a remote backend | Superseded by 0010 |
| [0003](0003-plan-gated-apply-pipeline.md) | Gate every apply behind a reviewer-approved, frozen plan artifact | Accepted |
| [0004](0004-reuse-pr-plan-on-merge.md) | Reuse the PR's reviewed plan on merge instead of re-planning | Accepted — amends 0003 |
| [0005](0005-sticky-pr-plan-comment.md) | Sticky, self-deleting PR plan comment | Accepted |
| [0006](0006-conventional-commit-title-only.md) | Lint PR titles against Conventional Commits, not every commit | Accepted |
| [0007](0007-dependabot-scope.md) | Dependabot scoped to terraform, github-actions, devcontainers | Accepted |
| [0008](0008-squash-merge-only.md) | This repo merges PRs via squash-merge only | Accepted |
| [0009](0009-one-module-per-repo.md) | One Terraform module call per managed repository | Accepted |
| [0010](0010-s3-state-backend.md) | Migrate Terraform state to an S3 backend, in this repo | Accepted — supersedes 0002 |
| [0011](0011-sse-s3-not-kms-for-state-bucket.md) | State bucket uses SSE-S3 (AES256), not SSE-KMS with a customer managed key | Accepted |
| [0012](0012-plan-jobs-drop-production-environment.md) | Plan jobs don't declare `environment: production`; only apply does | Accepted — amends 0010 |
| [0013](0013-oidc-immutable-subject-claims.md) | Tolerate GitHub's immutable OIDC subject claims with `@*` wildcards | Accepted — amends 0010 |
| [0014](0014-topics-not-prefix-for-repo-taxonomy.md) | Tag repo category with GitHub topics, not a name prefix | Accepted |
| [0015](0015-terraform-pr-path-filter-superset.md) | `terraform-pr.yml`'s path filter must be a superset of `terraform-apply.yml`'s | Accepted — amends 0004 |
| [0016](0016-multi-repo-oidc-trust-shared-state.md) | Multiple repos share one OIDC trust and one state object | Superseded by 0017 |
| [0017](0017-per-repo-oidc-trust-and-state-isolation.md) | Per-repo OIDC trust and state isolation, not a shared role pair | Accepted — supersedes 0016 |
| [0018](0018-plan-role-trusts-optional-repo-environment-claim.md) | Plan/apply role trust names each repo's environment gate, not a hardcoded "production" | Accepted |
| [0019](0019-move-per-repo-ci-roles-out-of-bootstrap.md) | Move per-repo CI IAM role generation out of bootstrap/, into the main repo | Accepted — supersedes 0010, amends 0017; amended by 0020 |
| [0020](0020-modularize-ci-roles.md) | Modularize per-repo CI IAM role generation into `modules/aws/tf-iams` | Accepted — amends 0019 |
| [0021](0021-migrate-plan-apply-actions-to-shared-repo.md) | Migrate `terraform-pr.yml`/`terraform-apply.yml`'s composite actions to NerdIT-Tech/.github | Accepted |
