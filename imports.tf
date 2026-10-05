# Declarative import for infra-terraform's own github_repository resource
# (repositories.tf's module "infra_terraform" block) -- the repo already
# exists, so its first apply must adopt the live resource instead of trying
# to create one with a name GitHub will reject as already taken. Goes
# through the normal PR + plan-gated apply pipeline (ADR-0003): the plan
# shows "1 resource to import", a reviewer approves it like any other
# change, and CI's apply job performs the import. See ADR-0023 and
# bootstrap/README.md's "Migrating an existing repo's role pair out of
# bootstrap" for the same technique used for gitops's AWS role pair.
#
# Delete this file once a subsequent `terraform plan` comes back clean (0
# to add/change/destroy) -- its job is done at that point, same as the
# now-deleted import for gitops.
import {
  to = module.infra_terraform.github_repository.this
  id = "infra-terraform"
}
