# bootstrap

Creates the shared AWS backend this org's Terraform repos' state lives in --
one S3 bucket (with native state locking), a GitHub Actions OIDC trust
provider, and (as of [ADR-0019](../docs/adr/0019-move-per-repo-ci-roles-out-of-bootstrap.md))
**exactly one** repo's plan/apply IAM role pair: `infra-terraform`'s own.
See [ADR-0010](../docs/adr/0010-s3-state-backend.md) for the shared-bucket
decision, [ADR-0017](../docs/adr/0017-per-repo-oidc-trust-and-state-isolation.md)
for the role-pair-per-repo mechanism, and ADR-0019 for why every *other*
repo's role pair now lives in the main repo's `ci-roles.tf` instead, not
here.

`infra-terraform`'s own role pair is the one exception that has to stay
here: it has the same chicken-and-egg problem as the bucket itself -- CI
can't create the credentials it needs to run itself.

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
4. `terraform apply`. This creates the bucket, `infra-terraform`'s plan/apply
   role pair (including the IAM-management policy that lets its apply role
   create every other repo's role pair from the main repo -- ADR-0019), and
   prints the ARNs in the `role_arns` output (e.g.
   `role_arns["infra-terraform"].plan`).
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

## Adding a Terraform-consuming repo

As of ADR-0019, this is no longer a `bootstrap/` change. Add an entry to
the main repo's `var.ci_repositories` instead -- see the main
[README.md](../README.md#adding-a-terraform-consuming-repo) for that
workflow. `bootstrap/` only ever gets a new repo entry again if
`infra-terraform` itself were ever renamed (it won't be) -- there is no
other reason to touch `var.repositories` here.

## Migrating an existing repo's role pair out of bootstrap

This only applies to a role pair that was created here *before* ADR-0019
(today: `gitops`'s). `moved {}` blocks (see `moved.tf`) only rewrite a
resource's address within one state -- they can't move a resource from
`bootstrap/`'s state into the main repo's state, since those are two
separate backends.

The **import half is declarative**, not a hand-typed CLI command: the main
repo's [`imports.tf`](../imports.tf) has an `import {}` block per resource
(Terraform >= 1.5), naming the exact real AWS role/policy each one adopts.
This goes through the **normal PR + plan-gated apply pipeline** (ADR-0003)
-- `terraform plan` shows "N resource(s) will be imported", a reviewer
approves it like any other change, and CI's apply job performs the
import. No manual AWS credentials needed for this half.

The **removal half still has to be a manual `terraform state rm`**, not a
`removed {}` block: Terraform's `removed` block only accepts a whole
resource address as `from` (e.g. `aws_iam_role.plan`), not one instance of
a `for_each`/`count` resource (e.g. `aws_iam_role.plan["gitops"]`) --
confirmed against the actual Terraform release this repo pins, not
assumed from docs. Since `aws_iam_role.plan`/`.apply` here are `for_each`
resources with a live `"infra-terraform"` instance that must keep being
managed, there's no way to tell Terraform "drop only the `"gitops"` key"
declaratively. `terraform state rm` only removes Terraform's *record* of a
resource -- it makes no AWS API call, so the real roles are untouched:

```sh
terraform state rm \
  'aws_iam_role.plan["gitops"]' \
  'aws_iam_role.apply["gitops"]' \
  'aws_iam_role_policy.plan_state_access["gitops"]' \
  'aws_iam_role_policy.apply_state_access["gitops"]'
```

Order:

1. Merge the main repo's `imports.tf` + that repo's `var.ci_repositories`
   entry (already done for `gitops`) and let CI apply it normally. Confirm
   with `terraform plan` in the main repo that it comes back clean
   (0 to add/change/destroy) -- that's confirmation the import adopted the
   live resources rather than describing something new.
2. Only then, run the `terraform state rm` command above by hand against
   `bootstrap/`'s backend (`gitops`'s entry is already gone from
   `var.repositories`, so don't run `terraform apply` here until *after*
   this step -- otherwise it will plan to destroy the real roles). Doing
   this second keeps `bootstrap/`'s state as a fallback record of
   `gitops`'s roles until step 1 is confirmed to have worked.
3. `terraform plan` in `bootstrap/` should now come back clean. Delete
   `imports.tf` (main repo) once its plan is clean too -- its job is done,
   and leaving it in is harmless but dead weight.

## Changing this config later

Any change here (rotating a role, widening a trust condition, etc.) is a
normal `terraform plan`/`apply` against the backend configured in step 5 --
just make sure you're authenticated as a principal with access to the
bucket/table/roles, not the CI roles themselves (they intentionally can't
reach this config's state).
