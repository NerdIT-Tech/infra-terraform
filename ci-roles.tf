# AWS CI role pairs for every Terraform-consuming repo except infra-terraform
# itself, whose own plan/apply roles stay in bootstrap/ (chicken-and-egg --
# CI can't create the credentials it needs to run itself). Every other
# repo's role pair is generated here, applied through this repo's normal
# plan-gated pipeline (ADR-0003) instead of a hand-run bootstrap/ apply --
# see ADR-0019. Logic pulled directly from bootstrap/main.tf's original
# for_each block, just re-scoped to var.ci_repositories.
#
# To add a repo: add an entry to var.ci_repositories (variables.tf), then
# read its plan/apply ARNs from the ci_role_arns output (outputs.tf) and
# set them as that repo's own TF_AWS_PLAN_ROLE_ARN/TF_AWS_APPLY_ROLE_ARN
# Actions variables.

# Looked up, not recreated -- AWS allows only one OIDC provider per URL per
# account, and bootstrap/ already created (or adopted) this one.
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
}

locals {
  # State object + lockfile ARNs per repo, one pair per entry in that repo's
  # state_keys list (keyed the same as var.ci_repositories).
  ci_repo_state = {
    for name, cfg in var.ci_repositories : name => {
      state_object_arns = [
        for key in cfg.state_keys : "${data.aws_s3_bucket.terraform_state.arn}/${key}"
      ]
      # Native S3 locking (`use_lockfile`, Terraform >= 1.10) writes a companion
      # object at this path via conditional PutObject/DeleteObject -- a separate
      # object from the state itself, so the read-only plan role can take/release
      # the lock without ever gaining write access to the actual state data.
      state_lockfile_arns = [
        for key in cfg.state_keys : "${data.aws_s3_bucket.terraform_state.arn}/${key}.tflock"
      ]
    }
  }
}

# --- Plan roles: read-only, one per repo in var.ci_repositories. Assumed by
# that repo's terraform-pr.yml (any PR) and terraform-apply.yml's plan job
# (push to main / workflow_dispatch). A PR plan can never write state, no
# matter what it plans -- see ADR-0010. Each repo gets its own role, trusted
# only by its own OIDC token and scoped only to its own state_keys -- see
# ADR-0017.

data "aws_iam_policy_document" "plan_trust" {
  for_each = var.ci_repositories

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringLike"
      # `@*` after each name tolerates this org's immutable subject claims
      # (GitHub embeds the org/repo's stable numeric ID) -- see ADR-0013. If
      # this repo's plan job declares its own `environment:` (each.value.plan_environment
      # set), its OIDC sub claim REPLACES the pull_request/ref shape below
      # with an environment one, so that pattern has to be matched too,
      # alongside them, not instead of them -- see ADR-0018.
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        [
          "repo:${var.github_owner}@*/${each.key}@*:pull_request",
          "repo:${var.github_owner}@*/${each.key}@*:ref:refs/heads/main",
        ],
        each.value.plan_environment != null ? ["repo:${var.github_owner}@*/${each.key}@*:environment:${each.value.plan_environment}"] : []
      )
    }
  }
}

resource "aws_iam_role" "plan" {
  for_each           = var.ci_repositories
  name               = "${each.key}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust[each.key].json
}

data "aws_iam_policy_document" "plan_state_access" {
  for_each = var.ci_repositories

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = each.value.state_keys
    }
  }
  statement {
    sid       = "StateObjectRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = local.ci_repo_state[each.key].state_object_arns
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.ci_repo_state[each.key].state_lockfile_arns
  }
}

resource "aws_iam_role_policy" "plan_state_access" {
  for_each = var.ci_repositories
  name     = "terraform-state-read"
  role     = aws_iam_role.plan[each.key].id
  policy   = data.aws_iam_policy_document.plan_state_access[each.key].json
}

# --- Apply roles: read-write, one per repo in var.ci_repositories. Assumed
# only by that repo's apply job, which only ever runs on main under a
# required-reviewer environment gate (ADR-0003) -- "production" by default,
# or each.value.apply_environment when a repo names its gate differently
# (e.g. gitops's homelab gate) -- see ADR-0018.

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.ci_repositories

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringLike"
      # A job that declares `environment: <name>` (as the apply job must, to
      # reach the GitHub App secrets scoped to that environment) gets an
      # environment-based sub claim -- this REPLACES the ref-based one, it
      # doesn't add to it. See ADR-0012. `@*` after each name tolerates this
      # org's immutable subject claims -- see ADR-0013.
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@*/${each.key}@*:environment:${each.value.apply_environment}"]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each           = var.ci_repositories
  name               = "${each.key}-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

data "aws_iam_policy_document" "apply_state_access" {
  for_each = var.ci_repositories

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = each.value.state_keys
    }
  }
  statement {
    sid       = "StateObjectReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = local.ci_repo_state[each.key].state_object_arns
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.ci_repo_state[each.key].state_lockfile_arns
  }
}

resource "aws_iam_role_policy" "apply_state_access" {
  for_each = var.ci_repositories
  name     = "terraform-state-read-write"
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.apply_state_access[each.key].json
}
