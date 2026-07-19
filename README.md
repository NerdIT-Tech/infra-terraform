# infra-terraform

Terraform for `NerdIT-Tech`'s GitHub-managed assets — repositories today,
teams/permissions/etc. as they're added later.

> **Why things are built this way:** this README covers *what* runs and
> *how* to set it up. For the reasoning behind a choice — what was
> considered and rejected, and what it obligates future changes to respect
> — see [`docs/adr/`](docs/adr/README.md).

## Structure

- `modules/github-repository/` — reusable module wrapping `github_repository`
  and (optionally) branch protection on its default branch. Every managed
  repo is one module call, not a copy-pasted resource block
  ([ADR-0009](docs/adr/0009-one-module-per-repo.md)).
- `repositories.tf` — one `module` block per repository this org manages.
- `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf` — root wiring.
- `bootstrap/` — a separate, rarely-touched Terraform config that creates
  this repo's own state backend (S3 bucket, DynamoDB lock table, CI's AWS
  IAM roles). Applied by hand, never by CI — see
  [`bootstrap/README.md`](bootstrap/README.md) and
  [ADR-0010](docs/adr/0010-s3-state-backend.md).

### Adding a repository

Copy the `module "servicenow_sdk_for_go"` block in `repositories.tf`, give it
a new module name and `name`, and adjust the other arguments. See
`modules/github-repository/variables.tf` for everything that's configurable
(visibility, topics, merge settings, branch protection, etc).

## Authentication

Terraform authenticates to GitHub as a **GitHub App**, not a personal access
token ([ADR-0001](docs/adr/0001-github-app-auth.md)).

### One-time setup

1. In the `NerdIT-Tech` org, go to **Settings → Developer settings → GitHub
   Apps → New GitHub App**.
2. Give it a name (e.g. `nerdit-infra-terraform`), disable the webhook (not
   needed), and set these **repository permissions**:
   - **Administration**: Read & write (create/configure repos)
   - **Contents**: Read & write (branch protection, initial commit)
   - **Metadata**: Read-only (required baseline)
   - Add more later as this repo grows to manage more asset types (e.g.
     **Members**/**Administration** at the org level for teams).
3. Create the App, note the **App ID**.
4. Generate a **private key** (downloads a `.pem` file) — store it somewhere
   outside this repo, e.g. a secrets manager or local path excluded from git.
5. Install the App on `NerdIT-Tech`, scoped to the repositories it should
   manage (or "All repositories" if that's simpler for an org-wide tool).
   Note the **Installation ID** (visible in the installation's URL).

### Running Terraform locally

The provider reads GitHub App credentials from the environment — they're
never written into `.tf`, `.tfvars`, or state:

```sh
export GITHUB_APP_ID="..."
export GITHUB_APP_INSTALLATION_ID="..."
export GITHUB_APP_PEM_FILE="/path/to/private-key.pem"

terraform init
terraform plan
```

## State

State lives in an S3 bucket, locked via a DynamoDB table
([ADR-0010](docs/adr/0010-s3-state-backend.md), which supersedes the
earlier Actions-cache approach in
[ADR-0002](docs/adr/0002-local-state-via-actions-cache.md)). The bucket,
lock table, and CI's AWS IAM roles are created by
[`bootstrap/`](bootstrap/README.md) — a separate config, applied by hand,
never by CI.

`versions.tf`'s `backend "s3" {}` block is empty on purpose: bucket/region/
lock-table are account-specific values supplied via `-backend-config` at
`terraform init` time, not hardcoded. Locally:

```sh
terraform init \
  -backend-config="bucket=<TF_STATE_BUCKET>" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=<AWS_REGION>" \
  -backend-config="dynamodb_table=<TF_STATE_DYNAMODB_TABLE>"
```

CI authenticates to AWS via GitHub Actions OIDC (`aws-actions/configure-aws-credentials`),
assuming one of two IAM roles created by `bootstrap/`:

- `TF_AWS_PLAN_ROLE_ARN` — read-only, used by `terraform-pr.yml` and by
  `terraform-apply.yml`'s `plan` job. Can't write state under any
  circumstances, so a PR plan can never corrupt it.
- `TF_AWS_APPLY_ROLE_ARN` — read-write, used only by `terraform-apply.yml`'s
  `apply` job, which only runs under the `production` environment gate.

### One-time AWS setup

1. Run `bootstrap/` by hand — see [`bootstrap/README.md`](bootstrap/README.md)
   for the full chicken-and-egg procedure (it creates its own bucket, then
   migrates its own state into it).
2. Note the outputs: `state_bucket`, `lock_table`, `plan_role_arn`,
   `apply_role_arn`.
3. **Settings → Secrets and variables → Actions → Variables**, add:
   - `AWS_REGION`
   - `TF_STATE_BUCKET` — `state_bucket` output
   - `TF_STATE_DYNAMODB_TABLE` — `lock_table` output
   - `TF_AWS_PLAN_ROLE_ARN` — `plan_role_arn` output
   - `TF_AWS_APPLY_ROLE_ARN` — `apply_role_arn` output

No AWS secrets are needed — auth is OIDC role assumption, not static keys.

## CI/CD

Three workflows under `.github/workflows/`, plus Dependabot:

- **`terraform-pr.yml`** — runs on every pull request that touches `*.tf`
  files: `fmt -check`, `validate`, TFLint, a Trivy config scan, then a
  read-only `terraform plan` posted/updated as a sticky PR comment and
  uploaded as a `tfplan` build artifact. Assumes the read-only AWS role, so
  it can never write state.
- **`terraform-apply.yml`** — runs on push to `main` and via manual
  `workflow_dispatch`.
  - `resolve-pr` checks whether the push is a merged PR; if so, `plan`
    reuses that PR's already-reviewed `tfplan` artifact instead of
    re-planning ([ADR-0004](docs/adr/0004-reuse-pr-plan-on-merge.md)).
    Otherwise it plans fresh.
  - `apply` runs under the `production` GitHub Environment (required
    reviewer approval) and applies the exact `tfplan` artifact, never a
    plan recomputed at apply time
    ([ADR-0003](docs/adr/0003-plan-gated-apply-pipeline.md)).
  - `cleanup-pr-comment` deletes the sticky plan comment from the PR once
    a merge-triggered apply succeeds
    ([ADR-0005](docs/adr/0005-sticky-pr-plan-comment.md)).
- **`conventional-commits.yml`** — lints the PR title (only) against
  [Conventional Commits](https://www.conventionalcommits.org/)
  ([ADR-0006](docs/adr/0006-conventional-commit-title-only.md)).
- **Dependabot** (`.github/dependabot.yml`) — weekly updates for Terraform,
  GitHub Actions, and devcontainer versions
  ([ADR-0007](docs/adr/0007-dependabot-scope.md)).

This repo merges PRs via **squash-merge only**
([ADR-0008](docs/adr/0008-squash-merge-only.md)).

### One-time repo setup for CI

In the repo's **Settings**:

1. **Settings → Environments** → create `production`, add required
   reviewers. This is what gates every apply.
2. **Settings → Secrets and variables → Actions**:
   - Secret `TF_GITHUB_APP_PEM` — the **base64** of the GitHub App private
     key file, not the raw PEM text: `base64 -w0 app-private-key.pem`.
     Pasting the raw multi-line PEM directly into the secret box is prone
     to newline mangling (GitHub API errors with `no decodeable PEM data
     found` if this happens) — base64 sidesteps that entirely.
   - Variable `TF_GITHUB_APP_ID` — the App ID.
   - Variable `TF_GITHUB_APP_INSTALLATION_ID` — the installation ID.
   - `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_DYNAMODB_TABLE`,
     `TF_AWS_PLAN_ROLE_ARN`, `TF_AWS_APPLY_ROLE_ARN` — see
     [One-time AWS setup](#one-time-aws-setup).
3. **Settings → Branches** → add a protection rule for `main` requiring
   the `Plan` (from `terraform-pr.yml`) and `Lint PR title` status checks,
   and "Require branches to be up to date before merging" (see
   [ADR-0004](docs/adr/0004-reuse-pr-plan-on-merge.md) for why the latter
   matters).
4. **Settings → General → Pull Requests** → uncheck "Allow merge commits"
   and "Allow rebase merging", keep "Allow squash merging" checked, and set
   "Default commit message for squash merges" to **"Pull request title"**
   ([ADR-0008](docs/adr/0008-squash-merge-only.md)).

Once `bootstrap/` has run and the variables above are set, no further setup
is needed — the first `terraform apply` against the new backend starts from
an empty state and creates everything.
