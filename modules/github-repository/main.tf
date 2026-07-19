resource "github_repository" "this" {
  name         = var.name
  description  = var.description
  visibility   = var.visibility
  homepage_url = var.homepage_url
  topics       = var.topics

  has_issues   = var.has_issues
  has_wiki     = var.has_wiki
  has_projects = var.has_projects

  # auto_init ensures the repo has a default branch to protect and seed
  # with the gitignore/license templates below.
  auto_init          = true
  gitignore_template = var.gitignore_template
  license_template   = var.license_template

  allow_squash_merge     = var.allow_squash_merge
  allow_merge_commit     = var.allow_merge_commit
  allow_rebase_merge     = var.allow_rebase_merge
  delete_branch_on_merge = var.delete_branch_on_merge
}

resource "github_repository_vulnerability_alerts" "this" {
  count = var.vulnerability_alerts ? 1 : 0

  repository = github_repository.this.name
  enabled    = true
}

resource "github_branch_protection" "default" {
  count = var.enable_branch_protection ? 1 : 0

  repository_id = github_repository.this.node_id
  pattern       = var.default_branch

  enforce_admins         = var.enforce_admins
  require_signed_commits = var.require_signed_commits

  required_pull_request_reviews {
    required_approving_review_count = var.required_approving_review_count
    require_code_owner_reviews      = var.require_code_owner_reviews
  }

  dynamic "required_status_checks" {
    for_each = length(var.required_status_checks) > 0 ? [1] : []

    content {
      strict   = true
      contexts = var.required_status_checks
    }
  }
}
