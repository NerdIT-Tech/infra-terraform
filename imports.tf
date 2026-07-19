# One-time import blocks for repositories migrated from being unmanaged to
# being managed by this repo. Terraform no-ops an import block once the
# resource is already in state, so these are safe to leave briefly but
# should be deleted in a follow-up PR once the migration apply has run.

import {
  to = module.pkg_linux.github_repository.this
  id = "pkg-linux"
}

import {
  to = module.pkg_linux.github_repository_vulnerability_alerts.this[0]
  id = "pkg-linux"
}

import {
  to = module.secret_lifecycle_orchestrator.github_repository.this
  id = "secret-lifecycle-orchestrator"
}

import {
  to = module.secret_lifecycle_orchestrator.github_repository_vulnerability_alerts.this[0]
  id = "secret-lifecycle-orchestrator"
}

import {
  to = module.infra_runners.github_repository.this
  id = "infra-runners"
}

import {
  to = module.infra_runners.github_repository_vulnerability_alerts.this[0]
  id = "infra-runners"
}
