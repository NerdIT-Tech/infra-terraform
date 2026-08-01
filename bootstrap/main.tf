# Shared state bucket + per-repo GitHub Actions OIDC trust for this org's
# Terraform repos. Bootstrapped once by hand (see README.md) -- never
# applied by CI. Each repo in var.repositories gets its own plan/apply role
# pair, scoped to exactly that repo's own state object -- no repo's CI ever
# gets credentials broad enough to touch another repo's state, this
# bootstrap config's own state, or anything outside the one bucket it owns.
# See ADR-0016.

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

#trivy:ignore:AWS-0132 SSE-S3 (AES256) is a deliberate choice, not an oversight -- see ADR-0011.
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

  # One state object + lockfile per repo, keyed the same as var.repositories.
  repo_state = {
    for name, cfg in var.repositories : name => {
      state_object_arn = "${aws_s3_bucket.terraform_state.arn}/${cfg.state_key}"
      # Native S3 locking (`use_lockfile`, Terraform >= 1.10) writes a companion
      # object at this path via conditional PutObject/DeleteObject -- a separate
      # object from the state itself, so the read-only plan role can take/release
      # the lock without ever gaining write access to the actual state data.
      state_lockfile_arn = "${aws_s3_bucket.terraform_state.arn}/${cfg.state_key}.tflock"
    }
  }
}

# --- Plan roles: read-only, one per repo in var.repositories. Assumed by
# that repo's terraform-pr.yml (any PR) and terraform-apply.yml's plan job
# (push to main / workflow_dispatch). A PR plan can never write state, no
# matter what it plans -- same invariant ADR-0002 called out for the old
# cache-based setup. Each repo gets its own role, trusted only by its own
# OIDC token and scoped only to its own state_key -- see ADR-0016.

data "aws_iam_policy_document" "plan_trust" {
  for_each = var.repositories

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
      test = "StringLike"
      # `@*` after each name tolerates this org's immutable subject claims
      # (GitHub embeds the org/repo's stable numeric ID: e.g.
      # repo:NerdIT-Tech@194043185/infra-terraform@1305370731:pull_request,
      # not the plain repo:OWNER/REPO:... format most docs show). See
      # ADR-0013.
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}@*/${each.key}@*:pull_request",
        "repo:${var.github_owner}@*/${each.key}@*:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  for_each           = var.repositories
  name               = "${each.key}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust[each.key].json
}

data "aws_iam_policy_document" "plan_state_access" {
  for_each = var.repositories

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [each.value.state_key]
    }
  }
  statement {
    sid       = "StateObjectRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [local.repo_state[each.key].state_object_arn]
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [local.repo_state[each.key].state_lockfile_arn]
  }
}

resource "aws_iam_role_policy" "plan_state_access" {
  for_each = var.repositories
  name     = "terraform-state-read"
  role     = aws_iam_role.plan[each.key].id
  policy   = data.aws_iam_policy_document.plan_state_access[each.key].json
}

# --- Apply roles: read-write, one per repo in var.repositories. Assumed
# only by that repo's terraform-apply.yml apply job, which only ever runs
# on main under the `production` environment gate (ADR-0003).

data "aws_iam_policy_document" "apply_trust" {
  for_each = var.repositories

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
      test = "StringLike"
      # A job that declares `environment: production` (as terraform-apply.yml's
      # apply job must, to reach the GitHub App secrets scoped to that
      # environment) gets an environment-based sub claim -- this REPLACES the
      # ref-based one, it doesn't add to it. See ADR-0012. `@*` after each
      # name tolerates this org's immutable subject claims (embeds the
      # org/repo's stable numeric ID) -- see ADR-0013.
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}@*/${each.key}@*:environment:production"]
    }
  }
}

resource "aws_iam_role" "apply" {
  for_each           = var.repositories
  name               = "${each.key}-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust[each.key].json
}

data "aws_iam_policy_document" "apply_state_access" {
  for_each = var.repositories

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]
    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [each.value.state_key]
    }
  }
  statement {
    sid       = "StateObjectReadWrite"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = [local.repo_state[each.key].state_object_arn]
  }
  statement {
    sid       = "StateLockFile"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [local.repo_state[each.key].state_lockfile_arn]
  }
}

resource "aws_iam_role_policy" "apply_state_access" {
  for_each = var.repositories
  name     = "terraform-state-read-write"
  role     = aws_iam_role.apply[each.key].id
  policy   = data.aws_iam_policy_document.apply_state_access[each.key].json
}
