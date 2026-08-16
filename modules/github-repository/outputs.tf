output "name" {
  description = "Repository name, as passed to var.name -- exposed so other configs (e.g. github-app-installations.tf) can reference it instead of retyping the string."
  value       = github_repository.this.name
}

output "full_name" {
  description = "Full repository name, in \"owner/name\" form."
  value       = github_repository.this.full_name
}

output "html_url" {
  description = "URL to the repository on github.com."
  value       = github_repository.this.html_url
}

output "node_id" {
  description = "GraphQL global node ID of the repository."
  value       = github_repository.this.node_id
}

output "repo_id" {
  description = "REST API repository ID."
  value       = github_repository.this.repo_id
}
