terraform {
  # >= 1.10 for the S3 backend's native `use_lockfile` locking (ADR-0010).
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Bucket/region are supplied via -backend-config at init time (see
  # .github/workflows/*.yml and README.md#state), not hardcoded here --
  # they're account-specific values created by bootstrap/, not a fixed part
  # of this config. See ADR-0010.
  backend "s3" {}
}
