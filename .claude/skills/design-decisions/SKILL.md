---
name: design-decisions
description: >
  Points to this repo's (infra-terraform) Architecture Decision Records in
  docs/adr/ -- the deliberate trade-offs behind GitHub App auth instead of a
  PAT, local Terraform state persisted via GitHub Actions cache instead of a
  remote backend, the terraform-pr/terraform-apply workflow split with
  shared concurrency and plan-reuse-on-merge, sticky PR plan comments,
  squash-merge-only, conventional-commit title checks, Dependabot scope,
  and more. Consult this BEFORE proposing or making changes to auth,
  Terraform state/backend, the CI/CD workflows, branch protection,
  merge/commit conventions, or the module structure in this repo -- these
  are not accidents or defaults, they were chosen over real alternatives
  for stated reasons, and changing them without knowing why risks silently
  undoing a considered trade-off. Also consult it before answering any "why
  does this repo do X" / "why not just do Y instead" question. Use it
  proactively even when not asked explicitly -- e.g. before suggesting a
  remote Terraform backend, a different merge strategy, or a different auth
  mechanism.
---

# Design decisions

This repo records its architectural and process trade-offs as ADRs in
[`docs/adr/`](../../../docs/adr/README.md) — **not** in README.md. README
covers what runs and how to set it up; `docs/adr/` covers why, what was
rejected, and what a change here has to respect. Keeping them separate is
deliberate: cramming rationale into README turns it into a decision log
nobody can navigate, and duplicating the same reasoning in two places means
it drifts out of sync the first time only one copy gets updated.

Before touching an area covered by an ADR, or answering a "why"/"should we
change this" question:

1. Read [`docs/adr/README.md`](../../../docs/adr/README.md) — it's a short
   index table, safe to read in full.
2. Read the specific ADR(s) that cover the area you're about to touch.
3. If what you're about to do would contradict an ADR, say so explicitly
   and confirm with the user first — don't just quietly change course.
   Several of these decisions look like the "wrong" choice in isolation
   (local state instead of a real backend; a PR's title linted but not its
   commits) and are only correct in the context of the trade-off the ADR
   records.

## Keeping the catalog current

This is a living document, not a one-time snapshot. When a **real
architectural or process trade-off** gets decided in conversation —
something with a rejected alternative and a reason, the kind of thing a new
contributor would otherwise have to reverse-engineer from git blame — add a
new ADR:

1. Copy [`docs/adr/template.md`](../../../docs/adr/template.md) to the next
   sequential number, e.g. `docs/adr/0010-<short-title>.md`.
2. Fill in Context / Decision / Alternatives considered / Consequences.
   Write Consequences with a future reader in mind: what does this obligate
   them to check before they change something nearby.
3. Add a row to the table in `docs/adr/README.md`.
4. If the new ADR changes or replaces an earlier one, don't edit the old
   file's decision — mark it `Superseded by ADR-00NN` in its Status line
   and in the index, the way [ADR-0004](../../../docs/adr/0004-reuse-pr-plan-on-merge.md)
   is marked as amending [ADR-0003](../../../docs/adr/0003-plan-gated-apply-pipeline.md)
   instead of rewriting it. The history of *why it changed* is itself worth
   keeping.

Routine bug fixes, formatting, or anything already fully explained by the
diff/commit message don't need an ADR. And if a change you're about to make
would only be correctly understood by *also* updating README's factual
"what/how" description (not its reasoning), update that too — ADRs and
README should never describe two different realities.
