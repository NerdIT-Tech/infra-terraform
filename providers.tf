# GitHub App credentials are never set here. Deliberately omitting the
# app_auth block: the provider picks up GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID,
# and GITHUB_APP_PEM_FILE from the environment on its own, so credentials
# never end up in a .tf file, a .tfvars file, or version control. See
# README.md for how to create and install the GitHub App.
provider "github" {
  owner = var.github_owner
}
