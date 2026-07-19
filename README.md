# infra-terraform

Terraform for `NerdIT-Tech`'s GitHub-managed assets — repositories today,
teams/permissions/etc. as they're added later.

## Structure

- `modules/github-repository/` — reusable module wrapping `github_repository`
  and (optionally) branch protection on its default branch. Every managed
  repo is one module call, not a copy-pasted resource block.
- `repositories.tf` — one `module` block per repository this org manages.
- `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf` — root wiring.

### Adding a repository

Copy the `module "servicenow_sdk_for_go"` block in `repositories.tf`, give it
a new module name and `name`, and adjust the other arguments. See
`modules/github-repository/variables.tf` for everything that's configurable
(visibility, topics, merge settings, branch protection, etc).

## Authentication

Terraform authenticates to GitHub as a **GitHub App**, not a personal access
token — this scopes access to an installation rather than a person's account
and isn't tied to anyone leaving the org.

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

State is **local** (`terraform.tfstate`, gitignored) — there's no `backend`
block in `versions.tf`. For CI this is made to work by persisting
`terraform.tfstate` in the GitHub Actions cache between runs (see CI/CD
below) rather than migrating to a remote backend. That's a deliberate
trade-off, not the ideal setup — see the caveat below.

## CI/CD

Three workflows under `.github/workflows/`, plus Dependabot:

- **`terraform-pr.yml`** — runs on every pull request that touches `*.tf`
  files. `fmt -check`, `validate`, TFLint, and a Trivy config scan, then a
  read-only `terraform plan` whose output is posted/updated as a **sticky**
  PR comment (same comment is edited in place across pushes, keyed by an
  HTML marker). Never writes to the state cache. The saved plan
  (`tfplan`) is also uploaded as a build artifact so a later merge can
  reuse it — see below.
- **`terraform-apply.yml`** — runs on push to `main` (and via manual
  `workflow_dispatch`).
  - A `resolve-pr` job first checks whether the push is a merge of a PR
    (via GitHub's "list pull requests associated with a commit" API). If
    so, the `plan` job **downloads that PR's already-reviewed `tfplan`
    artifact instead of re-planning** — apply always runs exactly what was
    shown to the reviewer on the PR, never a plan recomputed after merge.
    Direct pushes to `main` and `workflow_dispatch` runs have no
    associated PR, so `plan` falls back to planning fresh for those.
  - `plan` uploads `tfplan` (whichever source) and the pre-apply state as
    build artifacts.
  - `apply` runs under the `production` GitHub Environment, which pauses
    for a required reviewer's approval (the plan is visible in the job
    summary) before downloading that exact `tfplan` artifact and applying
    it. Nothing auto-applies unattended.
  - Once apply succeeds for a merge-triggered run, a `cleanup-pr-comment`
    job deletes the sticky plan comment from the now-merged PR — it's
    been applied, so leaving the stale plan sitting on a closed PR is
    just noise.
  - **Caveat:** reusing a PR's plan is only safe if nothing else changed
    the managed state between when that plan was generated and when the
    PR merged. If the saved plan is stale relative to current state,
    `terraform apply` fails loudly (it will not silently re-plan and
    apply something unreviewed) — re-run via `workflow_dispatch` to plan
    fresh in that case. Requiring PR branches to be up to date before
    merge (branch protection) minimizes how often this happens.
- **`conventional-commits.yml`** — lints the PR title against
  [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`,
  `fix:`, `chore:`, etc.) using `amannn/action-semantic-pull-request`.
  Enforced on the title only, not every commit, since PRs here are merged
  with a merge commit and the title is what's meant to read as the
  semantic summary.
- **Dependabot** (`.github/dependabot.yml`) — weekly update PRs for
  Terraform providers/modules, GitHub Actions versions used in these
  workflows, and the devcontainer's pinned feature/image versions.

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
3. **Settings → Branches** → add a protection rule for `main` requiring
   the `Plan` (from `terraform-pr.yml`) and `Lint PR title` status checks,
   and "Require branches to be up to date before merging" (keeps the
   plan-reuse path in `terraform-apply.yml` safe from state drift between
   review and merge).

No other setup is needed — the state cache seeds itself on the first
successful apply (cache miss → empty state → normal `terraform apply`
creates everything and saves the cache for next time).

### Caveat: Actions cache as a state backend

Using `actions/cache` to persist `terraform.tfstate` avoids standing up a
remote backend, but it is **not** a real Terraform backend: no native
locking (the shared `concurrency: group: terraform-state` on both workflows
is the only thing preventing two runs from touching state at once), no
strong durability guarantee (caches can be evicted, e.g. after 7 days of
disuse), and cache keys can't be overwritten in place (the apply workflow
works around this by deleting the old entry before saving the new one,
which leaves a brief window with no cache entry). The apply workflow
mitigates the durability risk by also uploading `terraform.tfstate` as a
90-day build artifact before and after every apply, so a lost cache can be
recovered manually from the most recent artifact. If this repo starts
managing more than a handful of resources, migrating to a real backend
(HCP Terraform's free tier is the lowest-effort option, since it also
handles secret storage for the App credentials) is worth revisiting.
