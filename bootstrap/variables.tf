variable "aws_region" {
  description = "AWS region for the state bucket, lock table, and IAM resources. No default -- pick deliberately, it's awkward to move a bucket region later."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state (root config's state and this bootstrap config's own state, under different keys). No default -- bucket names are global across all of AWS, so this must be confirmed/changed before applying."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization the CI trust policies are scoped to. Matches the root config's github_owner variable."
  type        = string
  default     = "NerdIT-Tech"
}

variable "repositories" {
  description = "Repos (within github_owner) whose plan/apply IAM role pair is created here, in bootstrap/. As of ADR-0019, this is exactly infra-terraform -- its own role pair has the same chicken-and-egg problem as the state bucket itself (CI can't create the credentials it needs to run itself), so it's the one repo that can't move to the main repo's ci-roles.tf like every other repo does. Kept as a map (rather than inlining a single set of resources) so the existing for_each machinery in main.tf and the state addresses in moved.tf don't need to change. state_keys is a list, not a single key, because a repo can be structured as one Terraform root per service each with its own state key -- every listed key gets read (plan) or read/write (apply) access. plan_environment is optional: set it only if that repo's *plan* job itself declares `environment: <name>` (see ADR-0018) -- infra-terraform's plan job doesn't, per ADR-0012. apply_environment defaults to \"production\" (ADR-0003/ADR-0012's gate)."
  type = map(object({
    state_keys        = list(string)
    plan_environment  = optional(string)
    apply_environment = optional(string, "production")
  }))
  default = {
    "infra-terraform" = {
      state_keys = ["terraform.tfstate"]
    }
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider (https://token.actions.githubusercontent.com). AWS allows only one provider per URL per account -- set this to false and rely on the existing one if some other repo's CI setup already created it in this account."
  type        = bool
  default     = true
}
