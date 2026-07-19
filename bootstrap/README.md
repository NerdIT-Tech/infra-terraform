# bootstrap

Creates the shared AWS backend the root config's state lives in: an S3
bucket, a DynamoDB lock table, and the GitHub Actions OIDC trust (two IAM
roles -- read-only `plan`, read-write `apply`) the root config's CI uses to
reach them. See [ADR-0010](../docs/adr/0010-s3-state-backend.md) for why.

This is a one-time (or rarely-touched) setup, applied by hand with your own
AWS credentials -- **never** by CI. It is not one of this org's *managed*
assets; it's the plumbing the root config's state sits on top of.

## Chicken-and-egg: bootstrapping this config's own state

You can't store this bucket's state in the bucket it hasn't created yet. So
the first apply runs on local state, and only afterwards moves itself in:

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in
   `aws_region` and a globally-unique `state_bucket_name`.
2. Authenticate to AWS locally (whatever your normal method is -- SSO
   profile, etc.) with permissions to create S3 buckets, DynamoDB tables,
   IAM roles/policies, and (if `create_github_oidc_provider = true`, the
   default) an IAM OIDC provider.
3. `terraform init` (local state -- no backend block exists yet).
4. `terraform apply`. This creates the bucket, lock table, and both IAM
   roles, and prints their ARNs/names as outputs.
5. Add a backend block to `versions.tf` in *this* directory:

   ```hcl
   backend "s3" {
     bucket         = "<state_bucket_name from your tfvars>"
     key            = "bootstrap/terraform.tfstate"
     region         = "<aws_region from your tfvars>"
     dynamodb_table = "<lock_table_name, default nerdit-tech-terraform-locks>"
   }
   ```

6. `terraform init -migrate-state` and confirm. This config's own state now
   lives in the bucket it created, under a key (`bootstrap/terraform.tfstate`)
   the root config's CI roles have no access to (see `state_key` scoping in
   `main.tf`) -- keeping the invariant that CI can only ever touch the root
   config's own state object.
7. Delete the local `terraform.tfstate`/`terraform.tfstate.backup` left over
   from step 4 (they're gitignored, but no reason to keep a stale local copy
   once the migration in step 6 succeeds).

## Wiring the root config to this backend

After step 4's outputs are available, set these on the repo (**Settings →
Secrets and variables → Actions → Variables**) and add a matching `backend
"s3" {}` block to the root `versions.tf` -- see the main
[README.md](../README.md#state) for the full list and CI wiring.

## Changing this config later

Any change here (rotating a role, widening a trust condition, etc.) is a
normal `terraform plan`/`apply` against the backend configured in step 5 --
just make sure you're authenticated as a principal with access to the
bucket/table/roles, not the CI roles themselves (they intentionally can't
reach this config's state).
