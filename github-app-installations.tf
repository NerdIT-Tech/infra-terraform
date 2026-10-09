# Add one module block per GitHub App installation whose repository access
# this repo should manage. See modules/github-app-installation and
# README.md's "Adding a managed App installation" section for the manual
# one-time steps (create the App, install it, note its installation ID)
# that have to happen before a block here has anything to point at --
# GitHub has no API to create the App itself, only to manage which repos
# an already-installed one can see.
#
# module "example_bot" {
#   source = "./modules/github-app-installation"
#
#   installation_id = "12345678"
#   repositories    = ["some-repo", "another-repo"]
# }

locals {
  # Every repo this org's own Terraform manages (repositories.tf) needs the
  # Terraform App (ADR-0001) to be able to see it. Derived from those same
  # module blocks' name output, not retyped as string literals, so adding
  # or renaming a repo there can't silently drift out of sync with what
  # the App is granted here.
  terraform_managed_repos = [
    module.infra_terraform.name,
    module.servicenow_sdk_for_go.name,
    module.dot_github.name,
    module.tplink_omada_sdk_for_go.name,
    module.terraform_provider_omada.name,
    module.pkg_linux.name,
    module.secret_lifecycle_orchestrator.name,
    module.infra_runners.name,
    module.gitops.name,
  ]
}

# The Terraform App's own installation (id 147527608, visible at
# github.com/organizations/NerdIT-Tech/settings/installations/147527608)
# was installed with "All repositories" selected, not "Only select
# repositories" -- ADR-0022's Consequences flagged that this module fights
# an installation left on the default "all" scope. Declaring this block
# switches it to Terraform's explicit list below; every repo Terraform
# itself manages is included so the App never loses access to something it
# needs to keep managing, including infra-terraform's own repo (ADR-0023).
module "infra_terraform_app" {
  source = "./modules/github-app-installation"

  installation_id = "147527608"
  repositories    = local.terraform_managed_repos
}
