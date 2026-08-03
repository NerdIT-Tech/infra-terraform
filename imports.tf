# One-time migration (ADR-0019): adopts gitops's already-live plan/apply
# role pair -- created in bootstrap/ before this ADR, now declared in
# ci-roles.tf -- into this repo's state, instead of destroying and
# recreating those real AWS resources. `terraform plan` shows these as "N
# resource(s) will be imported"; a normal merge to main applies them
# through this repo's own plan-gated pipeline (ADR-0003) -- no manual
# `terraform import` CLI invocation, and no AWS credentials needed beyond
# the ones CI already has.
#
# Apply this (merge the PR) BEFORE running bootstrap/README.md's manual
# `terraform state rm` -- that way bootstrap/ still fully owns these
# resources as a fallback until this import is confirmed to have succeeded
# (`terraform plan` here comes back clean). Delete this file once that's
# confirmed -- its job is done.

import {
  to = aws_iam_role.plan["gitops"]
  id = "gitops-plan"
}

import {
  to = aws_iam_role.apply["gitops"]
  id = "gitops-apply"
}

import {
  to = aws_iam_role_policy.plan_state_access["gitops"]
  id = "gitops-plan:terraform-state-read"
}

import {
  to = aws_iam_role_policy.apply_state_access["gitops"]
  id = "gitops-apply:terraform-state-read-write"
}
