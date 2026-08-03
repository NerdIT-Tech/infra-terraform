# Preserves gitops's plan/apply role pair's state address across the switch
# from inline for_each resources (ADR-0019) to the modules/aws/tf-iams module
# (ADR-0020). Same physical AWS resources (role/policy names are unchanged --
# still derived as "${repo_name}-plan"/"-apply" -- so there's no rename to
# worry about either); only the address in *this repo's* state moves from a
# root resource keyed by repo name to a module instance keyed the same way.
#
# Harmless no-op if gitops's import (imports.tf) hadn't landed yet when this
# merges -- there's nothing at the "from" address for Terraform to move, and
# imports.tf's own "to" addresses have been updated to the module path
# directly, so the import proceeds normally either way.

moved {
  from = aws_iam_role.plan["gitops"]
  to   = module.ci_roles["gitops"].aws_iam_role.plan
}

moved {
  from = aws_iam_role.apply["gitops"]
  to   = module.ci_roles["gitops"].aws_iam_role.apply
}

moved {
  from = aws_iam_role_policy.plan_state_access["gitops"]
  to   = module.ci_roles["gitops"].aws_iam_role_policy.plan_state_access
}

moved {
  from = aws_iam_role_policy.apply_state_access["gitops"]
  to   = module.ci_roles["gitops"].aws_iam_role_policy.apply_state_access
}
