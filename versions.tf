terraform {
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Bucket/region/lock table are supplied via -backend-config at init time
  # (see .github/workflows/*.yml and README.md#state), not hardcoded here --
  # they're account-specific values created by bootstrap/, not a fixed part
  # of this config. See ADR-0010.
  backend "s3" {}
}
