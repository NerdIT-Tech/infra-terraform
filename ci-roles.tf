# AWS CI role pairs for every Terraform-consuming repo except infra-terraform
# itself, whose own plan/apply roles stay in bootstrap/ (chicken-and-egg --
# CI can't create the credentials it needs to run itself). Every other
# repo's role pair is generated here, applied through this repo's normal
# plan-gated pipeline (ADR-0003) instead of a hand-run bootstrap/ apply --
# see ADR-0019. The role pair itself is built by modules/aws/tf-iams/, one
# call per var.ci_repositories entry -- see ADR-0020 for why this moved from
# an inline for_each block (ADR-0019's original shape) into a module.
#
# To add a repo: add an entry to var.ci_repositories (variables.tf), then
# read its plan/apply ARNs from the ci_role_arns output (outputs.tf) and
# set them as that repo's own TF_AWS_PLAN_ROLE_ARN/TF_AWS_APPLY_ROLE_ARN
# Actions variables.

# ARNs constructed directly rather than looked up via data sources -- both
# are fully deterministic from inputs already available (S3 bucket ARNs
# have no account-ID component; the OIDC provider's ARN is just its fixed
# URL path under this account). A data source lookup would need its own
# IAM read grant (iam:ListOpenIDConnectProviders/GetOpenIDConnectProvider,
# s3:GetBucketLocation) on the read-only plan role just to resolve
# something computable from values already in hand -- unnecessary surface
# for a role ADR-0010 deliberately keeps minimal. aws_caller_identity needs
# no IAM grant at all (sts:GetCallerIdentity is allowed by default).
data "aws_caller_identity" "current" {}

locals {
  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  state_bucket_arn  = "arn:aws:s3:::${var.state_bucket_name}"
}

module "ci_roles" {
  source   = "./modules/aws/tf-iams"
  for_each = var.ci_repositories

  repo_name         = each.key
  github_owner      = var.github_owner
  oidc_provider_arn = local.oidc_provider_arn
  state_bucket_arn  = local.state_bucket_arn
  state_keys        = each.value.state_keys

  plan_refs         = each.value.plan_refs
  apply_refs        = each.value.apply_refs
  plan_environment  = each.value.plan_environment
  apply_environment = each.value.apply_environment
  plan_workflows    = each.value.plan_workflows
  apply_workflows   = each.value.apply_workflows
}
