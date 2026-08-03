# ARNs for the sub claim's fixed shapes are built here rather than passed in
# pre-formatted, so callers only ever hand this module raw inputs (branch
# names, environment names, workflow file names) -- see ADR-0013 for why the
# "@*" wildcards after the org and repo names are required, not cosmetic.
locals {
  state_object_arns   = [for key in var.state_keys : "${var.state_bucket_arn}/${key}"]
  state_lockfile_arns = [for key in var.state_keys : "${var.state_bucket_arn}/${key}.tflock"]

  repo_sub_prefix = "repo:${var.github_owner}@*/${var.repo_name}@*"

  # `pull_request` is always trusted for plan -- every PR's plan job runs
  # regardless of branch. plan_refs adds push-triggered branches (e.g. the
  # apply pipeline's own plan job, which runs on push to main);
  # plan_environment adds an environment-based pattern alongside these, not
  # instead of them (ADR-0018) -- a plan job might run other triggers that
  # never declare an environment.
  plan_sub_values = concat(
    ["${local.repo_sub_prefix}:pull_request"],
    [for branch in var.plan_refs : "${local.repo_sub_prefix}:ref:refs/heads/${branch}"],
    var.plan_environment != null ? ["${local.repo_sub_prefix}:environment:${var.plan_environment}"] : []
  )

  # apply_refs is opt-in and empty by default -- see its warning in
  # variables.tf. Unlike plan, apply has no unconditional pattern: apply
  # trust is environment-only unless a repo explicitly widens it.
  apply_sub_values = concat(
    ["${local.repo_sub_prefix}:environment:${var.apply_environment}"],
    [for branch in var.apply_refs : "${local.repo_sub_prefix}:ref:refs/heads/${branch}"]
  )

  plan_workflow_patterns  = [for wf in var.plan_workflows : "${var.github_owner}/${var.repo_name}/.github/workflows/${wf}@*"]
  apply_workflow_patterns = [for wf in var.apply_workflows : "${var.github_owner}/${var.repo_name}/.github/workflows/${wf}@*"]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_sub_values
    }
    dynamic "condition" {
      for_each = length(local.plan_workflow_patterns) > 0 ? [1] : []
      content {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:job_workflow_ref"
        values   = local.plan_workflow_patterns
      }
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.repo_name}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

data "aws_iam_policy_document" "plan_state_access" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = var.state_keys
    }
  }
  statement {
    sid       = "StateObjectRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = local.state_object_arns
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.state_lockfile_arns
  }
}

resource "aws_iam_role_policy" "plan_state_access" {
  name   = "terraform-state-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state_access.json
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_sub_values
    }
    dynamic "condition" {
      for_each = length(local.apply_workflow_patterns) > 0 ? [1] : []
      content {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:job_workflow_ref"
        values   = local.apply_workflow_patterns
      }
    }
  }
}

resource "aws_iam_role" "apply" {
  name               = "${var.repo_name}-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

data "aws_iam_policy_document" "apply_state_access" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = var.state_keys
    }
  }
  statement {
    sid       = "StateObjectReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = local.state_object_arns
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = local.state_lockfile_arns
  }
}

resource "aws_iam_role_policy" "apply_state_access" {
  name   = "terraform-state-read-write"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_state_access.json
}
