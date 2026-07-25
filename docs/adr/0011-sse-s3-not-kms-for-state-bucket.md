# ADR-0011: State bucket uses SSE-S3 (AES256), not SSE-KMS with a customer managed key

**Status:** Accepted
**Date:** 2026-07-25

## Context

Trivy's IaC scan (`terraform-pr.yml`, per [ADR-0010](0010-s3-state-backend.md))
flags `bootstrap/main.tf`'s `aws_s3_bucket_server_side_encryption_configuration`
as **AWS-0132 (HIGH)**: the bucket encrypts with `AES256` (SSE-S3, AWS-managed
keys) rather than SSE-KMS with a customer managed key (CMK), which would give
finer-grained control over key rotation, access policy, and audit logging via
CloudTrail.

## Decision

Keep `AES256`. The finding is suppressed inline in `bootstrap/main.tf` with
`#trivy:ignore:AWS-0132`, pointing at this ADR rather than silently
disappearing from scan output.

## Alternatives considered

- **SSE-KMS with a customer managed key** — the finding's own recommendation,
  and the more defensible default for a bucket holding genuinely sensitive
  data. Rejected here: it adds a new resource (the CMK), a key policy to
  maintain, and — since the `plan`/`apply` IAM roles in this same file would
  need `kms:Decrypt`/`kms:GenerateDataKey` scoped to that key — a third
  policy surface to keep in sync alongside the two S3 policies already
  scoping those roles to `state_key`. That's real ongoing complexity for a
  bucket that (a) already denies all non-TLS access
  (`terraform_state_bucket_policy`'s `DenyInsecureTransport` statement), (b)
  blocks all public access, and (c) holds Terraform state for a repo
  managing a handful of `github_repository` resources — not secrets, and not
  data whose confidentiality depends on which specific AWS principals can
  invoke a KMS key versus reach the bucket at all.
- **SSE-KMS with the AWS-managed `aws/s3` key** — a middle ground (still
  KMS-encrypted, no CMK to manage), but Trivy's AWS-0132 check specifically
  wants a *customer* managed key, so this wouldn't clear the finding anyway,
  and it adds KMS API call overhead/cost for no real access-control gain
  over SSE-S3 given (b) and (c) above.

## Consequences

- This bucket's data-at-rest encryption relies entirely on AWS-managed keys.
  If this bucket's contents ever change in kind (e.g. some other Terraform
  config's state gets stored here too and touches genuinely sensitive
  values), revisit this ADR — that's a materially different risk profile
  than the one this decision was made under.
- The suppression comment must keep citing this ADR. If someone reads
  `bootstrap/main.tf` cold and sees `#trivy:ignore:AWS-0132` with no
  pointer, they'd have to rediscover this reasoning from scratch.
- Same reasoning applies if bootstrap's own state (`bootstrap/terraform.tfstate`,
  living in the same bucket under its own key) is ever scanned separately —
  it's covered by the same bucket-level encryption setting.
