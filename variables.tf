variable "github_owner" {
  description = "GitHub organization that owns the managed repositories."
  type        = string
  default     = "NerdIT-Tech"
}

variable "state_bucket_name" {
  description = "Name of the shared Terraform state bucket created by bootstrap/ (same value as the TF_STATE_BUCKET Actions variable). No default -- it's an account-specific value, looked up here via a data source rather than recreated. Used by ci-roles.tf (ADR-0019) to scope every non-infra-terraform repo's IAM role pair to this one bucket."
  type        = string
}

variable "ci_repositories" {
  description = "Repos (within github_owner) other than infra-terraform that get their own AWS plan/apply IAM role pair, generated in ci-roles.tf. infra-terraform's own role pair stays in bootstrap/ -- it has the same chicken-and-egg problem as the state bucket itself (CI can't create the credentials it needs to run itself) -- see ADR-0019. Same shape as bootstrap's own var.repositories before ADR-0019, just for every OTHER repo now: one role pair per map entry, named \"<repo>-plan\"/\"<repo>-apply\", each scoped only to that repo's own state_keys -- no cross-repo access, by construction (ADR-0017). state_keys is a list, not a single key, because a repo can be structured as one Terraform root per service each with its own state key. plan_environment is optional: set it only if that repo's *plan* job itself declares `environment: <name>` (ADR-0018). apply_environment defaults to \"production\" (ADR-0003/ADR-0012's gate) -- override for a repo whose apply job is gated by a differently-named environment instead."
  type = map(object({
    state_keys        = list(string)
    plan_environment  = optional(string)
    apply_environment = optional(string, "production")
  }))
  default = {
    "gitops" = {
      # gitops/gha-runner/terraform.tfstate deliberately excluded: that
      # service is applied by hand only, never planned/applied by gitops's
      # own CI (see that repo's ADR-0005 and its terraform-pr.yml plan
      # matrix) -- no reason for this role to read it. Add it here if that
      # ever changes.
      state_keys = ["gitops/omada/terraform.tfstate"]
      # gitops's terraform-pr.yml plan job declares `environment: homelab`
      # to reach Proxmox connection secrets/vars scoped to that environment,
      # and its apply job is gated by that same homelab environment, not a
      # "production" one -- see ADR-0018.
      plan_environment  = "homelab"
      apply_environment = "homelab"
    }
  }
}
