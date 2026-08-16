# github_app_installation_repositories (plural) is the authoritative/
# declarative resource -- it owns the installation's whole repository set
# and prunes anything added outside Terraform, matching how the rest of
# this repo treats Terraform as the source of truth (e.g. github_repository
# in modules/github-repository). The singular github_app_installation_repository
# resource exists too, but it's additive-only and would let manual UI
# changes silently coexist instead of drifting back into line. See
# ADR-0022 for why creating the App itself stays a manual step instead.
resource "github_app_installation_repositories" "this" {
  installation_id       = var.installation_id
  selected_repositories = var.repositories
}
