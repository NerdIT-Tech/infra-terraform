output "state_bucket" {
  description = "S3 bucket holding Terraform state. Set as TF_STATE_BUCKET in the root repo's Actions variables."
  value       = aws_s3_bucket.terraform_state.id
}

output "role_arns" {
  description = "Plan (read-only) and apply (read-write) role ARNs per repo in var.repositories -- as of ADR-0019, that's exactly infra-terraform, e.g. role_arns[\"infra-terraform\"].plan / .apply. Every other repo's role ARNs come from the main repo's own outputs (module.<repo>_ci_role in ci-roles.tf), not from here."
  value = {
    for name, _ in var.repositories : name => {
      plan  = aws_iam_role.plan[name].arn
      apply = aws_iam_role.apply[name].arn
    }
  }
}
