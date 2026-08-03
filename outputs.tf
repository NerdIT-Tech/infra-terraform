output "servicenow_sdk_for_go_url" {
  description = "URL of the servicenow-sdk-for-go repository."
  value       = module.servicenow_sdk_for_go.html_url
}

output "ci_role_arns" {
  description = "Plan (read-only) and apply (read-write) AWS IAM role ARNs per repo in var.ci_repositories, e.g. ci_role_arns[\"gitops\"].plan / .apply. Set as that repo's own TF_AWS_PLAN_ROLE_ARN/TF_AWS_APPLY_ROLE_ARN Actions variables. See ADR-0019/ADR-0020."
  value = {
    for name, mod in module.ci_roles : name => {
      plan  = mod.plan_role_arn
      apply = mod.apply_role_arn
    }
  }
}
