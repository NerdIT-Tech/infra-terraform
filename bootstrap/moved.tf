# Preserves the already-applied infra-terraform-plan/apply roles' state
# addresses across the switch to per-repo for_each (ADR-0017) -- these
# physical resources are unchanged (same names), only their address in
# state moved from a single resource to a map keyed by repo name.

moved {
  from = aws_iam_role.plan
  to   = aws_iam_role.plan["infra-terraform"]
}

moved {
  from = aws_iam_role.apply
  to   = aws_iam_role.apply["infra-terraform"]
}

moved {
  from = aws_iam_role_policy.plan_state_access
  to   = aws_iam_role_policy.plan_state_access["infra-terraform"]
}

moved {
  from = aws_iam_role_policy.apply_state_access
  to   = aws_iam_role_policy.apply_state_access["infra-terraform"]
}
