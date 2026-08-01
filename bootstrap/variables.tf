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
  description = "Repos (within github_owner) that get their own AWS backend access. One plan/apply IAM role pair is created per map entry, named \"<repo>-plan\"/\"<repo>-apply\": each pair's trust policy matches only that repo's OIDC token, and its IAM policy is scoped only to that repo's own state_key -- no cross-repo access, by construction. Add a repo by adding a map entry; roles, trust policies, and state-access policies are generated automatically."
  type = map(object({
    state_key = string
  }))
  default = {
    "infra-terraform" = {
      state_key = "terraform.tfstate"
    }
    "gitops" = {
      state_key = "gitops/terraform.tfstate"
    }
  }
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider (https://token.actions.githubusercontent.com). AWS allows only one provider per URL per account -- set this to false and rely on the existing one if some other repo's CI setup already created it in this account."
  type        = bool
  default     = true
}
