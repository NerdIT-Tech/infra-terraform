output "installation_id" {
  description = "GitHub App installation ID this module manages repository access for."
  value       = github_app_installation_repositories.this.installation_id
}

output "repositories" {
  description = "Repository names the App installation currently has access to."
  value       = github_app_installation_repositories.this.selected_repositories
}
