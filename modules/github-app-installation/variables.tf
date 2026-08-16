variable "installation_id" {
  description = "GitHub App installation ID, visible in the installation's URL under the org's Settings -> GitHub Apps -> Configure page."
  type        = string
}

variable "repositories" {
  description = "Full set of repository names (in the same org this App is installed on) the App should have access to. This is authoritative: any repository added to the installation outside Terraform will be removed on the next apply."
  type        = list(string)
}
