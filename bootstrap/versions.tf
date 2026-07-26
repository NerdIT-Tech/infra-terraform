terraform {
  # >= 1.10 so this config can later self-migrate onto native S3 `use_lockfile`
  # locking too (see README.md step 5) -- matches the root config (ADR-0010).
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap starts on local state (nothing to point a backend at yet) and
  # migrates itself into the bucket it creates. See README.md in this
  # directory for the exact procedure -- do not add a backend block here
  # until that first apply has succeeded.
  backend "s3" {}
}
