# Add one module block per GitHub App installation whose repository access
# this repo should manage. See modules/github-app-installation and
# README.md's "Adding a managed App installation" section for the manual
# one-time steps (create the App, install it, note its installation ID)
# that have to happen before a block here has anything to point at --
# GitHub has no API to create the App itself, only to manage which repos
# an already-installed one can see.
#
# module "example_bot" {
#   source = "./modules/github-app-installation"
#
#   installation_id = "12345678"
#   repositories    = ["some-repo", "another-repo"]
# }
