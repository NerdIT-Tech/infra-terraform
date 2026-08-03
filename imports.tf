# One-time migration (ADR-0019): adopts gitops's already-live plan/apply
# role pair -- created in bootstrap/ before this ADR, now declared in
# ci-roles.tf via modules/aws/tf-iams (ADR-0020) -- into this repo's state,
# instead of destroying and recreating those real AWS resources. `terraform
# plan` shows these as "N resource(s) will be imported"; a normal merge to
# main applies them through this repo's own plan-gated pipeline (ADR-0003)
# -- no manual `terraform import` CLI invocation, and no AWS credentials
# needed beyond the ones CI already has.
#
# `to` addresses target the module path directly rather than the pre-ADR-0020
# root addresses -- if this import already completed before ADR-0020 landed,
# moved.tf carries the root address forward to this same module path, so
# these blocks become no-ops; if it hadn't, this imports straight into the
# final structure with no intermediate hop.
#
# Apply this (merge the PR) BEFORE running bootstrap/README.md's manual
# `terraform state rm` -- that way bootstrap/ still fully owns these
# resources as a fallback until this import is confirmed to have succeeded
# (`terraform plan` here comes back clean). Delete this file once that's
# confirmed -- its job is done.

import {
  to = module.ci_roles["gitops"].aws_iam_role.plan
  id = "gitops-plan"
}

import {
  to = module.ci_roles["gitops"].aws_iam_role.apply
  id = "gitops-apply"
}

import {
  to = module.ci_roles["gitops"].aws_iam_role_policy.plan_state_access
  id = "gitops-plan:terraform-state-read"
}

import {
  to = module.ci_roles["gitops"].aws_iam_role_policy.apply_state_access
  id = "gitops-apply:terraform-state-read-write"
}
