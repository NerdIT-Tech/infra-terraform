variable "repo_name" {
  description = "Name of the GitHub repository (within var.github_owner) this role pair belongs to. Derives role names (\"<repo_name>-plan\"/\"<repo_name>-apply\") and the OIDC sub claim's repo pattern."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization that owns repo_name. Combined with repo_name in every OIDC sub claim pattern, tolerant of GitHub's immutable subject claims via \"@*\" (ADR-0013)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created in bootstrap/) this role pair's trust policies federate with."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the shared Terraform state S3 bucket."
  type        = string
}

variable "state_keys" {
  description = "State object keys (within state_bucket_arn) this role pair may read (plan) or read/write (apply), plus each key's .tflock companion object."
  type        = list(string)
}

variable "plan_refs" {
  description = "Branch names (no \"refs/heads/\" prefix) whose push-triggered plan job is trusted, in addition to any pull_request run (always trusted) and plan_environment (if set). Matches the ref-based OIDC sub claim a push-triggered job without a declared `environment:` presents."
  type        = list(string)
  default     = ["main"]
}

variable "apply_refs" {
  description = <<-EOT
    Branch names (no "refs/heads/" prefix) additionally trusted for apply via
    a ref-based OIDC sub claim. Empty by default: apply trust is
    environment-only (see apply_environment), matching ADR-0003's
    required-reviewer gate.

    WARNING: a branch listed here can assume the read-write apply role from
    a push-triggered job that never declares `environment:`, bypassing that
    reviewer gate entirely for this repo. Only set this for a repo whose
    apply job intentionally runs outside an Environment gate and has some
    other, equivalent control in place.
  EOT
  type        = list(string)
  default     = []
}

variable "plan_environment" {
  description = "GitHub Actions environment name the plan job declares, if any (ADR-0018). Adds an environment-based sub claim pattern alongside, not instead of, the pull_request/ref ones -- declaring `environment:` on a job replaces its sub claim's shape, so the trust policy has to offer both shapes to match either kind of run."
  type        = string
  default     = null
}

variable "apply_environment" {
  description = "GitHub Actions environment name the apply job's required-reviewer gate is declared under (ADR-0003/ADR-0012)."
  type        = string
  default     = "production"
}

variable "plan_workflows" {
  description = <<-EOT
    Workflow file names (e.g. "terraform-pr.yml") the plan role's trust is
    additionally scoped to, matched against the OIDC job_workflow_ref claim
    (ANDed with the sub claim condition, not a substitute for it). Empty
    (default) applies no workflow restriction beyond the sub claim -- prior
    behavior.

    NOTE: unlike the sub claim's "@*" wildcard treatment -- root-caused
    against a real decoded token, see ADR-0013 -- this claim's exact shape
    under this org's immutable-subject-claims setting has not been verified
    against a live token. Confirm it (same debug-step approach ADR-0013
    used) before depending on this for a repo where getting it wrong would
    either wrongly deny a legitimate run or wrongly admit one.
  EOT
  type        = list(string)
  default     = []
}

variable "apply_workflows" {
  description = "Same as plan_workflows, scoping the apply role's trust instead."
  type        = list(string)
  default     = []
}
