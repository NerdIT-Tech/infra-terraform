---
name: add-repository
description: Use whenever the user asks to "add a repository", "create a new repo in Terraform", "add a GitHub repo to infra-terraform", "manage a new repository with Terraform", or wants to define a new repository module. This skill adds a properly formatted module block to repositories.tf following repo conventions, runs formatting/validation checks, and prepares the change for commit/PR.
---

# Add Repository Skill

This skill helps you add a new GitHub repository managed by the `infra-terraform` repository. It follows the established patterns in `repositories.tf`, respects Architectural Decision Records (ADRs), and keeps changes consistent with this codebase.

## When to use
- User wants to add a new GitHub repository managed by Terraform
- User says "add repo X", "create terraform entry for repo", or similar
- Adding any new module block to `repositories.tf`

## Prerequisites
- Working in the `infra-terraform` repository
- Understand the target repository details (name, visibility, description, topics, branch protection needs)

## Steps

### 1) Understand current conventions
- Read `repositories.tf` to see existing module blocks and ordering/style.
- Read `modules/github-repository/variables.tf` to understand available inputs and defaults.
- Consult the `design-decisions` skill for repo conventions (ADR-0014: use topics not name prefixes for infra; ADR-0001/0003/0023 context as relevant).
- Note existing patterns: infra repos typically get `topics = ["infrastructure", ...]`, public vs private, branch protection settings, merge settings.

### 2) Gather repository details
Ask the user for (or infer from request):
- Repository name (e.g. `homeassistant-iac`, `my-service`)
- Description (clear, concise)
- Visibility (`public` or `private`) — default public if not specified
- Topics (e.g. `["infrastructure", "terraform", "home-assistant"]`). For infra/tooling, include `"infrastructure"`.
- Auto-init? Usually `false` if importing existing repo with content; `true` only if creating brand new empty repo via Terraform (rare here).
- Branch protection: enabled/disabled. If enabled, `required_approving_review_count` (0 for solo-maintained) and `required_status_checks` (commonly `["Plan", "Lint PR title"]`).
- Merge settings: `allow_squash_merge`, `allow_merge_commit`, `allow_rebase_merge`, `delete_branch_on_merge`. Match similar repos (e.g. gitops uses squash+merge allowed, rebase false, delete on merge true).
- Pages/wiki/projects as needed.

### 3) Add the module block
Add a new module block to `repositories.tf`, following the exact style of existing blocks. Place it logically near similar repos or at the end — maintain consistent formatting and comments.

Use this template structure:
```hcl
module "repo_name_snake_case" {
  source = "./modules/github-repository"

  name        = "repo-name-kebab"
  description = "..."
  visibility  = "public"
  topics      = ["infrastructure", ...]
  auto_init   = false

  # optional settings...
  enable_branch_protection        = true
  required_approving_review_count = 0
  required_status_checks          = ["Plan", "Lint PR title"]
}
```

Convert repo name to snake_case for module name (e.g. `homeassistant-iac` → `homeassistant_iac`).

### 4) Format and validate
- Run `terraform fmt -recursive` to ensure formatting.
- Run `terraform validate` to catch syntax/config issues (note: may fail if modules not installed; that’s expected in some environments — report the result).

### 5) Prepare for commit/PR
- Stage the change (`git add repositories.tf`).
- Commit following Conventional Commits: `feat: add <repo-name> repository module` with a brief body.
- Create a feature branch if not already on one (use `branch` skill if helpful).
- Push and open PR (use `commit-push-pr` skill or standard git/gh). Include "no-issue-required" label if no related issue.

## Notes
- Never modify other repos' settings without reason.
- If the repo might already exist and needs importing, note that imports are handled in `imports.tf` separately — this skill only adds the module definition.
- Follow ADR guidance: for infra repos include "infrastructure" topic; avoid relying on name prefixes.
- Keep changes minimal and consistent with surrounding style.