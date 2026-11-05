---
name: agent-creator
description: Create new OpenCode agents (Markdown agent definitions with model, permissions, and system prompt). Make sure to use this skill whenever the user wants to create an agent, subagent, primary agent, assistant profile, or reusable AI role for OpenCode, even if they don't say "agent" explicitly.
---

# Agent Creator

A skill for designing, writing, and validating OpenCode agents.

## What an agent is

An agent = system prompt + model preference + permissions + display details, as a named reusable profile. Spec: https://opencode.ai/v2/docs/agents/

## Locations

```text
~/.config/opencode/agents/<name>.md   # global
.opencode/agents/<name>.md           # project
```

Nested paths become part of the ID: `.opencode/agents/team/reviewer.md` → `team/reviewer`.
JSONC alternative: `agents` key in any opencode config file.

## Frontmatter fields

| Field | Notes |
| --- | --- |
| `description` | One line on what the agent does. Shown to the model choosing which subagent to launch — make it specific and trigger-worthy. |
| `mode` | `primary` (default), `subagent`, or `all`. |
| `model` | `provider/model#variant`, e.g. `anthropic/claude-sonnet-4-5#high`. Omit to inherit the session model. |
| `permissions` | Ordered list of `{action, resource, effect}`, last match wins. |
| `steps` | Max model steps; on the last step tools are removed and it must summarize. |
| `hidden` | Remove from listings/subagent catalog (visibility, not security). |
| `color` | `#rrggbb` UI color. |
| `disabled` | Remove a built-in or custom agent. |

Permission actions: `shell`, `edit`, `subagent`, `read`, `glob`, `grep`, `webfetch`, `websearch`, `skill`, `*`. Effects: `allow`, `ask`, `deny`. Resources are paths/commands/agent IDs, `*` = all. Broad rule first, exceptions after.

The Markdown body IS the system prompt.

## Template

```md
---
description: Reviews database migrations for safety
mode: subagent
model: anthropic/claude-sonnet-4-5#high
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
---

Review migrations. List findings in severity order with file and line references. Do not modify files.
```

## Writing the system prompt (industry best practices)

Treat it as an **operating manual, not a personality sketch**:

1. **Job statement first.** What the agent is, what it owns, where it stops. Include explicit scope boundaries — what it should NOT do.
2. **Be specific.** Name output format, length, audience, constraints. Vague guidance produces inconsistent behavior.
3. **Minimal altitude.** Clear, direct instructions at the right altitude: not brittle hardcoded logic, not high-level hand-waving. Start minimal with a good model; add instructions only where evals show failure.
4. **Examples over adjectives.** 2–5 diverse canonical examples of the expected output behavior beat long rule lists. If you find yourself writing an edge-case laundry list, replace it with examples.
5. **Failure behavior.** Define what to do when data is missing/unclear: ask, state the assumption, escalate. Otherwise the agent guesses differently each run.
6. **Separate instructions from data.** Use delimiters (`<context>`, `---`, code fences) so pasted/retrieved content is treated as untrusted input.
7. **Tool guidance.** Say which tools to use, and when *not* to use them. Prefer fewer, well-described tools.
8. **No static data.** IDs, paths, and runtime values get injected at runtime, not baked into the prompt.
9. **Declare exact output.** If the agent must return something specific (verdict, report, file), name the format explicitly.
10. **Role drift is fine.** A tight role boundary helps consistency; a one-line "you are a senior X" persona is enough — don't write biographies.

## Permissions: least privilege

Default-deny for subagents that only analyze (deny `edit`, usually `shell`). Allow read-only discovery (`read`, `glob`, `grep`). Scope `shell` to the commands the agent actually needs. The child session uses its own permissions; the parent's `subagent` permissions gate which agents it may launch.

## Evaluating the agent before "ready"

Borrow the skill-creator loop:

1. **Write 2–4 realistic test prompts** the kind a user would actually say — the situations this agent is built for, plus one adjacent/edge case.
2. **Run it headlessly**:
   ```bash
   opencode run --agent <name> --model <provider/model> --auto "<prompt>"
   ```
   Clear, `--auto`, check the output against what you promised in the description.
3. **Check both qualitatively and quantitatively**: did it follow the format? Stay in scope? Use the right permissions (no surprise edits/shell calls)? Start failing on the edge case — tighten the prompt where it failed.
4. **Iterate**: edit the agent file, rerun the same prompts, compare. An agent is "ready" when all prompts produce the promised behavior without prompting hints.
5. Optional for rigor: spawn the agent on the same prompt via the `subagent` tool from a parent session to confirm it works as a child agent, not just as a primary.

Debug checklist when behavior is off: description too vague (model picks wrong agent/mode) · steps too low (runs out of budget) · permissions too broad (edits files it shouldn't) · system prompt vague on output format · missing failure-behavior instruction.

## Common pitfalls

- Writing a persona essay instead of operational rules.
- Forgetting `mode: subagent` on agents meant only for child sessions (a new custom agent defaults to `primary`).
- Overlapping tool permissions — a subagent that can edit defeats the point of a reviewer agent.
- Legacy V1 fields (`temperature`, `tools`, `maxSteps`, `prompt`) in V2 config — use `request`, `permissions`, `steps`, `system` instead.
