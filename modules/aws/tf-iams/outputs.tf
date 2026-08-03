output "plan_role_arn" {
  description = "ARN of the read-only plan IAM role."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "ARN of the read-write apply IAM role."
  value       = aws_iam_role.apply.arn
}
