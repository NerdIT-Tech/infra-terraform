# Add one module block per repository this org manages. To add the next
# repository, copy this block, change the module name/`name`, and adjust
# the other arguments as needed.
#
# Tag repos that are infrastructure/tooling (not an app or library) with
# `topics = ["infrastructure", ...]` -- see ADR-0014. This replaces naming
# convention (an `infra-` prefix) as the way to identify them.

module "servicenow_sdk_for_go" {
  source = "./modules/github-repository"

  name        = "servicenow-sdk-for-go"
  description = "Go SDK for the ServiceNow REST API."
  visibility  = "public"
  topics      = ["servicenow", "sdk", "go", "golang"]

  gitignore_template = "Go"
  license_template   = "mit" # TODO: confirm license choice

  enable_branch_protection        = true
  required_approving_review_count = 1
}

module "dot_github" {
  source = "./modules/github-repository"

  name        = ".github"
  description = "GitHub configuration files."
  visibility  = "public"
  topics      = ["github", "github-actions", "github-templates", "github-workflows"]

  license_template = "mit" # TODO: confirm license choice

  enable_branch_protection        = true
  required_approving_review_count = 1
}

module "tplink_omada_sdk_for_go" {
  source = "./modules/github-repository"

  name        = "tplink-omada-sdk-for-go"
  description = "Go SDK for the TP-Link Omada Controller API." # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["tplink", "omada", "sdk", "go", "golang"]

  gitignore_template = "Go"
  license_template   = "mit" # TODO: confirm license choice

  enable_branch_protection        = true
  required_approving_review_count = 0

  # enable_pages is temporarily disabled: the Terraform GitHub App (ADR-0001)
  # doesn't have the Pages repository permission, so `terraform apply` fails
  # with "403 Resource not accessible by integration" on every run until
  # someone with admin access widens the App's permissions on GitHub's side
  # (ADR-0001's consequence: "the two have to be kept in sync manually since
  # the App's grants aren't themselves managed by this Terraform"). Re-enable
  # once that's done -- website/ still ships the docs.yml workflow that needs
  # Pages source set to "GitHub Actions" to publish (#63).
  enable_pages = false
  # (no-op comment: forces a fresh CI plan against current state, since
  # main's terraform-apply.yml run for #64 failed partway through)
}

module "terraform_provider_omada" {
  source = "./modules/github-repository"

  name        = "terraform-provider-omada"
  description = "Terraform provider for the TP-Link Omada Controller API, built on tplink-omada-sdk-for-go." # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["terraform-provider", "omada", "tplink", "go", "golang"]

  gitignore_template = "Go"
  license_template   = "mit" # TODO: confirm license choice

  enable_branch_protection        = true
  required_approving_review_count = 1
}

module "pkg_linux" {
  source = "./modules/github-repository"

  name        = "pkg-linux"
  description = "" # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["linux", "package-manager", "apt", "yum", "apk", "github-pages"]
  auto_init   = false

  has_wiki     = true
  has_projects = true

  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = false

  enable_branch_protection = false
}

module "secret_lifecycle_orchestrator" {
  source = "./modules/github-repository"

  name        = "secret-lifecycle-orchestrator"
  description = "" # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["go", "golang", "secrets", "security", "automation"]
  auto_init   = false

  has_wiki     = true
  has_projects = true

  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = false

  enable_branch_protection = false
}

module "infra_runners" {
  source = "./modules/github-repository"

  name        = "infra-runners"
  description = "" # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["infrastructure"]
  auto_init   = false

  has_wiki     = true
  has_projects = true

  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = false

  enable_branch_protection = false
}

module "gitops" {
  source = "./modules/github-repository"

  name        = "gitops"
  description = "" # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["infrastructure"]
  auto_init   = false

  has_wiki     = false
  has_projects = true

  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = false
  delete_branch_on_merge = true

  enable_branch_protection = false
}
