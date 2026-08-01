output "state_bucket" {
  description = "S3 bucket holding Terraform state. Set as TF_STATE_BUCKET in the root repo's Actions variables."
  value       = aws_s3_bucket.terraform_state.id
}

output "role_arns" {
  description = "Plan (read-only) and apply (read-write) role ARNs per repo, keyed by repo name (var.repositories' keys). Every repo -- including infra-terraform -- reads its own TF_AWS_PLAN_ROLE_ARN/TF_AWS_APPLY_ROLE_ARN from its own entry here, e.g. role_arns[\"infra-terraform\"].plan / .apply. Roles are not shared across repos, see ADR-0016."
  value = {
    for name, _ in var.repositories : name => {
      plan  = aws_iam_role.plan[name].arn
      apply = aws_iam_role.apply[name].arn
    }
  }
}
