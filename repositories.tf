# Add one module block per repository this org manages. To add the next
# repository, copy this block, change the module name/`name`, and adjust
# the other arguments as needed.

module "servicenow_sdk_for_go" {
  source = "./modules/github-repository"

  name        = "servicenow-sdk-for-go"
  description = "Go SDK for the ServiceNow REST API." # TODO: confirm/edit description
  visibility  = "public"
  topics      = ["servicenow", "sdk", "go", "golang"]

  gitignore_template = "Go"
  license_template   = "mit" # TODO: confirm license choice

  enable_branch_protection        = true
  required_approving_review_count = 1
}

# --- Migrated repositories (pre-existing, brought under management via import) ---
# Arguments below mirror each repo's actual current settings so the import
# is behavior-neutral. `enable_branch_protection` is left off for all three
# since none currently has a protection rule on `main` -- turning it on is
# a deliberate follow-up, not part of this migration.

module "pkg_linux" {
  source = "./modules/github-repository"

  name        = "pkg-linux"
  description = "" # TODO: confirm/edit description
  visibility  = "public"
  topics      = []
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
  topics      = []
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
  topics      = []
  auto_init   = false

  has_wiki     = true
  has_projects = true

  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = true
  delete_branch_on_merge = false

  enable_branch_protection = false
}
