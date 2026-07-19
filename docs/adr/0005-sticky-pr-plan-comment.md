# ADR-0005: Sticky, self-deleting PR plan comment

**Status:** Accepted
**Date:** 2026-07-19

## Context

`terraform-pr.yml` posts the plan output as a PR comment so a reviewer
doesn't have to open the Actions log. A PR can be pushed to many times
before merge (fixups, rebases, review feedback), and once merged the plan
comment's content has either been applied (via ADR-0004) or superseded.

## Decision

The comment is found-and-updated in place using an HTML marker
(`<!-- terraform-plan -->`) rather than posted fresh on every push:
`terraform-pr.yml` searches existing PR comments for the marker and edits
that comment if found, creates one if not. Once a merge-triggered apply
succeeds, a `cleanup-pr-comment` job in `terraform-apply.yml` deletes that
comment entirely from the now-merged PR.

## Alternatives considered

- **Post a new comment on every push** — simplest, but turns an
  actively-iterated PR into a wall of stale plan comments.
- **Leave the comment in place after merge** — the comment is accurate
  history, but it's also easy to mistake for "this is what will happen if
  you look at this PR again," when in fact it's already happened. Deleting
  it removes that ambiguity; the actual applied plan is still recoverable
  from the merge-triggered apply run's job summary and artifacts if ever
  needed.
- **Update the comment to say "Applied" instead of deleting it** —
  considered, but adds a permanent form of a comment for both merged and
  closed-without-merging PRs; deletion keeps a closed PR's comment history
  limited to actual review discussion.

## Consequences

- `cleanup-pr-comment` only runs when `resolve-pr` found a merged PR for
  the triggering push (see ADR-0004) — direct pushes and
  `workflow_dispatch` runs have no PR comment to clean up.
- If the `apply` job fails, `cleanup-pr-comment` is skipped (its `needs`
  dependency didn't succeed) — the stale plan comment is left in place
  deliberately, so there's still a visible record to debug against.
