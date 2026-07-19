output "state_bucket" {
  description = "S3 bucket holding Terraform state. Set as TF_STATE_BUCKET in the root repo's Actions variables."
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table" {
  description = "DynamoDB table used for state locking. Set as TF_STATE_DYNAMODB_TABLE in the root repo's Actions variables."
  value       = aws_dynamodb_table.terraform_lock.id
}

output "plan_role_arn" {
  description = "Read-only role for terraform-pr.yml / terraform-apply.yml's plan job. Set as TF_AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Read-write role for terraform-apply.yml's apply job only. Set as TF_AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.apply.arn
}
