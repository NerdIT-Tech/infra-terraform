variable "name" {
  description = "Repository name."
  type        = string
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Repository visibility: \"public\" or \"private\"."
  type        = string

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "visibility must be either \"public\" or \"private\"."
  }
}

variable "homepage_url" {
  description = "Repository homepage URL."
  type        = string
  default     = null
}

variable "topics" {
  description = "List of topics to apply to the repository."
  type        = list(string)
  default     = []
}

variable "has_issues" {
  description = "Enable GitHub Issues for the repository."
  type        = bool
  default     = true
}

variable "has_wiki" {
  description = "Enable the wiki for the repository."
  type        = bool
  default     = false
}

variable "has_projects" {
  description = "Enable GitHub Projects for the repository."
  type        = bool
  default     = false
}

variable "gitignore_template" {
  description = "gitignore template to seed the repository with (requires auto_init)."
  type        = string
  default     = null
}

variable "license_template" {
  description = "License template to seed the repository with (requires auto_init)."
  type        = string
  default     = null
}

variable "allow_squash_merge" {
  description = "Allow squash merges."
  type        = bool
  default     = true
}

variable "allow_merge_commit" {
  description = "Allow merge commits."
  type        = bool
  default     = false
}

variable "allow_rebase_merge" {
  description = "Allow rebase merges."
  type        = bool
  default     = false
}

variable "delete_branch_on_merge" {
  description = "Automatically delete head branches after merge."
  type        = bool
  default     = true
}

variable "vulnerability_alerts" {
  description = "Enable Dependabot vulnerability alerts."
  type        = bool
  default     = true
}

variable "default_branch" {
  description = "Name of the default branch, also used as the branch protection pattern."
  type        = string
  default     = "main"
}

variable "enable_branch_protection" {
  description = "Enable branch protection on the default branch."
  type        = bool
  default     = true
}

variable "required_approving_review_count" {
  description = "Number of approving reviews required before a PR can be merged."
  type        = number
  default     = 1
}

variable "require_code_owner_reviews" {
  description = "Require review from a code owner before a PR can be merged."
  type        = bool
  default     = false
}

variable "required_status_checks" {
  description = "List of status check contexts required to pass before merging."
  type        = list(string)
  default     = []
}

variable "enforce_admins" {
  description = "Enforce branch protection rules on repository administrators."
  type        = bool
  default     = false
}

variable "require_signed_commits" {
  description = "Require commits pushed to the default branch to be signed."
  type        = bool
  default     = true
}
