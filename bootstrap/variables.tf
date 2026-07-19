variable "aws_region" {
  description = "AWS region for the state bucket, lock table, and IAM resources. No default -- pick deliberately, it's awkward to move a bucket region later."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state (root config's state and this bootstrap config's own state, under different keys). No default -- bucket names are global across all of AWS, so this must be confirmed/changed before applying."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "nerdit-tech-terraform-locks"
}

variable "github_owner" {
  description = "GitHub organization the CI trust policies are scoped to. Matches the root config's github_owner variable."
  type        = string
  default     = "NerdIT-Tech"
}

variable "github_repository_name" {
  description = "Repository name (within github_owner) the CI trust policies are scoped to."
  type        = string
  default     = "infra-terraform"
}

variable "create_github_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider (https://token.actions.githubusercontent.com). AWS allows only one provider per URL per account -- set this to false and rely on the existing one if some other repo's CI setup already created it in this account."
  type        = bool
  default     = true
}

variable "plan_role_name" {
  description = "Name of the read-only IAM role assumed by terraform-pr.yml's plan job (and terraform-apply.yml's plan job, when it plans fresh instead of reusing a PR plan)."
  type        = string
  default     = "infra-terraform-plan"
}

variable "apply_role_name" {
  description = "Name of the read-write IAM role assumed only by terraform-apply.yml's apply job."
  type        = string
  default     = "infra-terraform-apply"
}

variable "state_key" {
  description = "S3 key the root config's state is stored under in the shared bucket. The plan/apply IAM roles are scoped to exactly this key -- they have no access to this bootstrap config's own state (stored under a different key, applied by hand with your own AWS credentials, never CI)."
  type        = string
  default     = "terraform.tfstate"
}
