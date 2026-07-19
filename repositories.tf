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
