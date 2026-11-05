---
name: design-decision
description: Write architecture/design decision records (ADRs) optimized for coding agents. Use whenever the user wants to record, document, or capture an architectural decision, a "we decided to..." moment, a new rule/convention for the codebase, or asks for an ADR — also when superseding or deprecating an existing decision.
---

# Design Decisions

Write Architecture Decision Records that coding agents can find, scope, follow, and verify — not prose a human skims and an agent guesses at.

## Where records live

All ADRs live in `docs/adrs/`, one file per decision, named `<NNNN>-<kebab-title>.md` (e.g. `docs/adrs/0007-image-rendering.md`). Create the directory if it does not exist. The set is append-only: never edit an accepted record to change its decision — add a new one that supersedes it and update the old one's `status`.

## Before writing

1. Read every existing file in `docs/adrs/`. New rules must not contradict existing ones; if they do, either supersede the older record or reconcile with the user first. Agents pick arbitrarily between conflicting rules, so conflicts are bugs.
2. Decide the scope: which file globs this decision governs. Narrow globs keep unrelated context out of sessions.

## Record format

Use this exact shape. Keep the whole file tight — under ~200 lines, and the rules section should be the part an agent reads every session.

```markdown
---
id: R-<AREA>-<NNN>
applies_to: ["**/*.tsx", "src/**/*.ts"]
status: accepted | superseded-by: R-<AREA>-<NNN> | deprecated
---

# <Short title>

MUST: <imperative rule>.
MUST NOT: <forbidden pattern>.
SHOULD: <recommendation, with the exception case>.

## Why

1-3 sentences: the constraint or incident that forces this decision. No backstory novels.

## Verify

    rg "<bad pattern>" src/ && echo "FAIL" || echo "OK"
```

Rules for the body:

- **Imperative, not prose.** "MUST use X. MUST NOT use Y." An agent follows keywords literally; it summarizes paragraphs unreliably.
- **Stable ID.** `R-<AREA>-<NNN>` (e.g. `R-IMG-001`) so commits, reviews, and other ADRs can cite it exactly.
- **Verifiable.** The `## Verify` block must be a command (rg, grep, lint, test) that exits non-zero or prints FAIL when the rule is broken. If a decision cannot be checked, say why in one line instead.
- **Token-aware.** Compress to the decision and the rule; link out to design docs for narrative.

## After writing

- Confirm the new record's globs and rules do not overlap-contradict another record's.
- If the decision replaces an older one, set the old file's `status: superseded-by: <new id>`.
- Report the file path and the rule IDs to the user.
