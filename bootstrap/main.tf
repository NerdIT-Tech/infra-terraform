# Shared state backend for this org's Terraform repos. Bootstrapped once by
# hand (see README.md) -- never applied by CI. Everything here is deliberately
# scoped to exactly what the root config's CI roles need; the root config
# never gets credentials broad enough to touch this bootstrap config's own
# state or anything outside the one bucket/table it owns.

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "terraform_state_bucket_policy" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.terraform_state.arn, "${aws_s3_bucket.terraform_state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_bucket_policy.json
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# --- GitHub Actions OIDC: no long-lived AWS access keys stored as repo
# secrets, matching ADR-0001's stance on GitHub App auth over a PAT.

data "aws_iam_openid_connect_provider" "github_actions" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's OIDC certificate chain against its own trusted CA
  # store, not this value -- the resource still requires it syntactically.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github_actions[0].arn : data.aws_iam_openid_connect_provider.github_actions[0].arn

  state_object_arn = "${aws_s3_bucket.terraform_state.arn}/${var.state_key}"
}

# --- Plan role: read-only. Assumed by terraform-pr.yml (any PR) and by
# terraform-apply.yml's plan job (push to main / workflow_dispatch). A PR
# plan can never write state, no matter what it plans -- same invariant
# ADR-0002 called out for the old cache-based setup.

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repository_name}:pull_request",
        "repo:${var.github_owner}/${var.github_repository_name}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = var.plan_role_name
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

data "aws_iam_policy_document" "plan_state_access" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [var.state_key]
    }
  }
  statement {
    sid       = "StateObjectRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [local.state_object_arn]
  }
  statement {
    sid       = "StateLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.terraform_lock.arn]
  }
}

resource "aws_iam_role_policy" "plan_state_access" {
  name   = "terraform-state-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state_access.json
}

# --- Apply role: read-write. Assumed only by terraform-apply.yml's apply
# job, which only ever runs on main under the `production` environment gate
# (ADR-0003).

data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repository_name}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name               = var.apply_role_name
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

data "aws_iam_policy_document" "apply_state_access" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [var.state_key]
    }
  }
  statement {
    sid       = "StateObjectReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = [local.state_object_arn]
  }
  statement {
    sid       = "StateLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.terraform_lock.arn]
  }
}

resource "aws_iam_role_policy" "apply_state_access" {
  name   = "terraform-state-read-write"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_state_access.json
}
