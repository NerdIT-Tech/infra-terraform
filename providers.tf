# GitHub App credentials are never set here. Deliberately omitting the
# app_auth block: the provider picks up GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID,
# and GITHUB_APP_PEM_FILE from the environment on its own, so credentials
# never end up in a .tf file, a .tfvars file, or version control. See
# README.md for how to create and install the GitHub App.
provider "github" {
  owner = var.github_owner
}

# Region is picked up from the AWS_REGION/AWS_DEFAULT_REGION env var that
# aws-actions/configure-aws-credentials already exports for the state
# backend (see README.md#state) -- not hardcoded here, same reasoning as
# the backend "s3" {} block below. Used by modules/terraform-ci-role/
# (ADR-0019) to create every Terraform-consuming repo's IAM role pair
# except infra-terraform's own, which stays in bootstrap/.
provider "aws" {}
