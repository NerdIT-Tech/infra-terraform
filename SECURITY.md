# Security Policy

## Supported versions

This repo has no release versions — `main` is continuously applied by CI
(see [`docs/adr/0003-plan-gated-apply-pipeline.md`](docs/adr/0003-plan-gated-apply-pipeline.md)).
Only the current state of `main` is supported; there is nothing else to
patch.

## Reporting a vulnerability

Please **do not** open a public issue for a security concern (e.g. a
misconfigured IAM trust policy, an overly broad GitHub App permission, a
credential leak, or a way to make CI apply unintended changes).

Instead, use GitHub's private reporting flow:
[Report a vulnerability](https://github.com/NerdIT-Tech/infra-terraform/security/advisories/new)
(**Security** tab → **Report a vulnerability**).

Include:

- The affected file(s)/resource(s) (e.g. a specific IAM policy statement,
  OIDC trust condition, or workflow).
- Steps to reproduce or the trust boundary that's crossed.
- Impact — what an attacker could do with it (e.g. cross-repo state
  access, privilege escalation via `ci-roles.tf`'s IAM management grant).

You should expect an initial response within 5 business days. Confirmed
issues are fixed and applied through the normal plan-gated pipeline; a
security-relevant fix does not skip review, since the reviewed plan is
itself part of the fix's verification.

## Scope

In scope: this repository's Terraform (`modules/`, `bootstrap/`, root
config), its GitHub Actions workflows, and the IAM/OIDC trust policies they
generate for `NerdIT-Tech`'s repos.

Out of scope: the security posture of individual application repos this
config manages (report those to the repo in question) and GitHub/AWS
platform vulnerabilities themselves (report those to GitHub/AWS directly).
