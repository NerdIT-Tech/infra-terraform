# bootstrap

Creates the shared AWS backend this org's Terraform repos' state lives in:
one S3 bucket (with native state locking), and a GitHub Actions OIDC trust
pair -- read-only `plan`, read-write `apply` -- **per repo** listed in
`var.repositories`. Each repo's pair is trusted only by that repo's OIDC
token and scoped only to that repo's own state object; no repo's CI can
touch another's state. See [ADR-0010](../docs/adr/0010-s3-state-backend.md)
for the shared-bucket decision and
[ADR-0016](../docs/adr/0016-per-repo-oidc-trust-and-state-isolation.md) for
the per-repo role isolation.

This is a one-time (or rarely-touched) setup, applied by hand with your own
AWS credentials -- **never** by CI. It is not one of this org's *managed*
assets; it's the plumbing the root config's state sits on top of.

## Chicken-and-egg: bootstrapping this config's own state

You can't store this bucket's state in the bucket it hasn't created yet. So
the first apply runs on local state, and only afterwards moves itself in:

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in
   `aws_region` and a globally-unique `state_bucket_name`.
2. Authenticate to AWS locally (whatever your normal method is -- SSO
   profile, etc.) with permissions to create S3 buckets, IAM roles/policies,
   and (if `create_github_oidc_provider = true`, the default) an IAM OIDC
   provider.
3. `terraform init` (local state -- no backend block exists yet).
4. `terraform apply`. This creates the bucket and one plan/apply role pair
   per repo in `var.repositories`, and prints their ARNs in the `role_arns`
   output -- a map keyed by repo name, each entry holding `.plan`/`.apply`
   (e.g. `role_arns["infra-terraform"].plan`).
5. Add a backend block to `versions.tf` in *this* directory:

   ```hcl
   backend "s3" {
     bucket       = "<state_bucket_name from your tfvars>"
     key          = "bootstrap/terraform.tfstate"
     region       = "<aws_region from your tfvars>"
     use_lockfile = true
   }
   ```

6. `terraform init -migrate-state` and confirm. This config's own state now
   lives in the bucket it created, under a key (`bootstrap/terraform.tfstate`)
   no repo's CI role has access to -- it isn't listed in `var.repositories`
   (see `repo_state` scoping in `main.tf`) -- keeping the invariant that CI
   can only ever touch its own repo's state object.
7. Delete the local `terraform.tfstate`/`terraform.tfstate.backup` left over
   from step 4 (they're gitignored, but no reason to keep a stale local copy
   once the migration in step 6 succeeds).

## Wiring the root config to this backend

After step 4's outputs are available, set these on the `infra-terraform`
repo (**Settings → Secrets and variables → Actions → Variables**) from
`role_arns["infra-terraform"].plan`/`.apply`, and add a matching `backend
"s3" {}` block to the root `versions.tf` -- see the main
[README.md](../README.md#state) for the full list and CI wiring.

## Adding a repo

1. Add an entry to `var.repositories` in `main.tf`'s caller (or
   `terraform.tfvars`), keyed by the repo name, with the S3 key its
   Terraform state should live under (e.g. `"gitops" = { state_key =
   "gitops/terraform.tfstate" }`). Use a key no other entry uses -- sharing
   a `state_key` between repos means sharing write access to that state,
   which defeats the isolation ADR-0016 is for.
2. `terraform apply` (see "Changing this config later" below). This creates
   a new `<repo>-plan`/`<repo>-apply` role pair, scoped only to that repo's
   `state_key`.
3. Read that repo's ARNs from `role_arns["<repo>"].plan`/`.apply` and set
   them as that repo's own `TF_AWS_PLAN_ROLE_ARN`/`TF_AWS_APPLY_ROLE_ARN`
   Actions variables -- mirroring the
   [Wiring](#wiring-the-root-config-to-this-backend) step above, just for
   that repo instead of `infra-terraform`.

## Changing this config later

Any change here (rotating a role, widening a trust condition, etc.) is a
normal `terraform plan`/`apply` against the backend configured in step 5 --
just make sure you're authenticated as a principal with access to the
bucket/table/roles, not the CI roles themselves (they intentionally can't
reach this config's state).
