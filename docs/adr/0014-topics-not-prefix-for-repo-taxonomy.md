# ADR-0014: Tag repo category with GitHub topics, not a name prefix

**Status:** Accepted
**Date:** 2026-07-26

## Context

Some repos this org manages are infrastructure/tooling (e.g.
`infra-runners`) rather than an application or library (e.g.
`servicenow-sdk-for-go`, `pkg-linux`). `infra-runners`'s name already
carries an `infra-` prefix, and it would have been easy to lean on that
convention going forward: name every infrastructure repo with an `infra-`
prefix and treat the name itself as the category signal.

## Decision

Use GitHub topics to mark category instead: `topics = ["infrastructure"]`
on the module block for any repo that's infrastructure/tooling rather than
an app or library. The `github-repository` module already exposes `topics`
as a plain list, so this needed no new mechanism -- just using the
existing field consistently. See `repositories.tf`'s header comment for
the convention.

## Alternatives considered

- **Name prefix (`infra-`)** -- rejected. A prefix is fixed at repo
  creation; changing a repo's category later means a rename, which breaks
  clone URLs, CI references, and bookmarks. It also only allows one
  category per repo, whereas topics stack (a repo can be `infrastructure`
  and `internal-tool` and a language tag at once). And a prefix baked into
  the name has no query surface -- topics are filterable via GitHub's
  search/API (`topic:infrastructure`).

## Consequences

- When adding a repo to `repositories.tf`, decide whether it's
  infrastructure/tooling and set `topics = ["infrastructure", ...]`
  accordingly -- there's no automatic derivation from the repo name.
- `infra-runners` keeps its existing name (renaming it is out of scope
  here); the `infra-` in its name is now just a legacy naming artifact, not
  the thing that identifies it as infrastructure.
- If more categories are needed later (e.g. `internal-tool`, `library`),
  extend the same `topics` convention rather than reintroducing a naming
  scheme.
