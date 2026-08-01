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
  description = "Repos (within github_owner) that get their own AWS backend access. One plan/apply IAM role pair is created per map entry, named \"<repo>-plan\"/\"<repo>-apply\": each pair's trust policy matches only that repo's OIDC token, and its IAM policy is scoped only to that repo's own state_keys -- no cross-repo access, by construction. state_keys is a list, not a single key, because a repo can be structured as one Terraform root per service each with its own state key (gitops's ADR-0004) rather than infra-terraform's single root -- every listed key gets read (plan) or read/write (apply) access, still scoped to just that repo's role pair. Add a repo (or a key to an existing repo) by editing this map; roles, trust policies, and state-access policies are generated automatically."
  type = map(object({
    state_keys = list(string)
  }))
  default = {
    "infra-terraform" = {
      state_keys = ["terraform.tfstate"]
    }
    "gitops" = {
      # gitops/gha-runner/terraform.tfstate deliberately excluded: that
      # service is applied by hand only, never planned/applied by gitops's
      # own CI (see that repo's ADR-0005 and its terraform-pr.yml plan
      # matrix) -- no reason for this role to read it. Add it here if that
      # ever changes.
      state_keys = ["gitops/omada/terraform.tfstate"]
    }
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider (https://token.actions.githubusercontent.com). AWS allows only one provider per URL per account -- set this to false and rely on the existing one if some other repo's CI setup already created it in this account."
  type        = bool
  default     = true
}
