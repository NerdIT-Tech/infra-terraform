terraform {
  required_version = ">= 1.6"

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
}
