# Claude Code Hooks — Full Reference

Pulled from https://code.claude.com/docs/en/hooks. Consult this file for exact field names and
schemas; SKILL.md only carries the parts needed to get a first hook working.

## Hook Events

| Event | Lifecycle | Description |
|-------|-----------|-------------|
| SessionStart | Once per session | When session begins or resumes |
| Setup | Once per session | Triggered by `--init-only`, `--init`, or `--maintenance` flags |
| UserPromptSubmit | Once per turn | Before Claude processes a user prompt |
| UserPromptExpansion | Once per turn | When user-typed command expands into a prompt |
| PreToolUse | Per tool call | Before a tool executes (can block) |
| PermissionRequest | Per tool call | When permission dialog appears |
| PermissionDenied | Per tool call | When tool denied by auto-mode classifier |
| PostToolUse | Per tool call | After tool succeeds |
| PostToolUseFailure | Per tool call | After tool fails |
| PostToolBatch | Per batch | After parallel tool calls resolve |
| Stop | Once per turn | When Claude finishes responding |
| SubagentStart | Per subagent | When subagent spawned |
| SubagentStop | Per subagent | When subagent finishes |
| TeammateIdle | Per teammate | When agent team teammate goes idle |
| TaskCreated | Per task | When task created via TaskCreate |
| TaskCompleted | Per task | When task marked completed |
| PreCompact | Per compaction | Before context compaction |
| PostCompact | Per compaction | After context compaction |
| CwdChanged | Per directory change | When working directory changes |
| FileChanged | Per file change | When watched file changes on disk |
| ConfigChange | Per config change | When configuration file changes |
| InstructionsLoaded | Per load | When CLAUDE.md loaded |
| Elicitation | Per MCP request | When MCP server requests user input |
| ElicitationResult | Per response | After user responds to MCP elicitation |
| WorktreeCreate | Per worktree | Before worktree creation |
| WorktreeRemove | Per worktree | When worktree removed |
| Notification | Per notification | When Claude Code sends notification |
| MessageDisplay | While streaming | While assistant message text displays |
| SessionEnd | Once per session | When session terminates |
| StopFailure | Once per turn | When turn ends due to API error |

## Exit Code Semantics

- **Exit 0** — success. Claude Code parses stdout for JSON. JSON is only processed on exit 0.
- **Exit 2** — blocking error. Stderr is fed to Claude as the error message; the action is blocked
  (exact effect depends on the event — see below).
- **Any other exit code** — non-blocking error. Execution continues; stderr shown to user only.

Use exit 2 for "block this", not exit 1 — exit 1 is silently non-blocking.

### Exit Code 2 Behavior by Event

| Event | Can block? | Behavior |
|-------|-----------|----------|
| PreToolUse, PermissionRequest | Yes | Blocks the action |
| UserPromptSubmit, UserPromptExpansion | Yes | Rejects/blocks the action |
| Stop, SubagentStop, TeammateIdle | Yes | Prevents the action from completing |
| TaskCreated, TaskCompleted, ConfigChange, PreCompact | Yes | Blocks/rolls back the action |
| PostToolUse, PostToolUseFailure, PostToolBatch | Yes | Stops the loop before the next model call |
| PostToolUse, PostToolUseFailure, PermissionDenied | No (already completed) | Output ignored |
| SessionStart, Setup, SubagentStart, Notification | No | stderr shown to user only |
| StopFailure | No | Output and exit code ignored |
| WorktreeCreate | Yes | Non-zero exit fails creation |

## JSON Output Schema (stdout, exit 0)

```json
{
  "continue": true,
  "stopReason": "message",
  "suppressOutput": false,
  "decision": "block",
  "reason": "explanation",
  "systemMessage": "warning text",
  "additionalContext": "context text",
  "terminalSequence": "ESC sequence",
  "hookSpecificOutput": {
    "hookEventName": "EventName",
    "permissionDecision": "deny",
    "permissionDecisionReason": "reason",
    "additionalContext": "context",
    "updatedInput": {},
    "updatedToolOutput": "output",
    "displayContent": "text",
    "action": "accept|decline|cancel",
    "retry": true,
    "decision": { "behavior": "allow|deny", "updatedInput": {} }
  }
}
```

Notes:
- `hookSpecificOutput.hookEventName` is required whenever `hookSpecificOutput` is present.
- `permissionDecision` is the field to use for PreToolUse allow/deny/ask/defer — not the
  top-level `decision`, which is a separate older field some events still honor.
- If nothing needs to happen, `exit 0` with no stdout (or an empty `{}`) is fine — the hook is a
  no-op and normal flow applies.

## Common Input Fields (stdin, all events)

```json
{
  "session_id": "uuid",
  "prompt_id": "uuid",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "EventName",
  "effort": { "level": "medium" },
  "agent_id": "uuid",
  "agent_type": "agent-name"
}
```

Event-specific fields ride alongside these — e.g. PreToolUse/PostToolUse add `tool_name` and
`tool_input` (and `tool_response` for PostToolUse); UserPromptSubmit adds `prompt`. Inspect
`hook_event_name` and print the raw stdin JSON while developing if the exact shape for an event
isn't obvious — the fields above are the only ones guaranteed to be present everywhere.

## Matcher Patterns

| Matcher value | Evaluation | Example |
|---------------|-----------|---------|
| `"*"`, `""`, omitted | Match all | Fires every time |
| Letters, digits, `_`, `-`, spaces, `,`, `\|` | Exact string or list | `Bash`, `Edit\|Write` |
| Contains other chars | JS regex (unanchored) | `^Notebook`, `mcp__.*__write.*` |

What the matcher compares against depends on the event:

| Event | Matches against |
|-------|-----------------|
| PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionDenied | Tool name (`Bash`, `Edit\|Write`) |
| SessionStart | Session source (`startup`, `resume`, `clear`, `compact`, `fork`) |
| Setup | CLI flag (`init`, `maintenance`) |
| SessionEnd | Exit reason (`clear`, `logout`, `other`) |
| Notification | Notification type (`permission_prompt`, `auth_success`) |
| SubagentStart, SubagentStop | Agent type (`Explore`, `Plan`, `code-reviewer`) |
| PreCompact, PostCompact | Compaction trigger (`manual`, `auto`) |
| ConfigChange | Config source (`user_settings`, `project_settings`, `policy_settings`) |
| StopFailure | Error type (`rate_limit`, `authentication_failed`, `invalid_request`) |
| FileChanged | Literal filenames (`.envrc\|.env`) |
| UserPromptExpansion | Command name |
| Elicitation, ElicitationResult | MCP server name |

MCP tools follow `mcp__<server>__<tool>` — e.g. `mcp__memory__.*` (all tools from one server),
`mcp__.*__write.*` (any write-shaped tool from any server).

## settings.json Wiring

### Locations

| Location | Scope | Shareable via git |
|----------|-------|--------------------|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes |
| `.claude/settings.local.json` | Single project | No |
| Managed policy settings | Organization-wide | Yes |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes |
| Skill/agent frontmatter | Component active | Yes |

### Shape

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh",
            "args": [],
            "timeout": 30,
            "async": false,
            "asyncRewake": false,
            "shell": "bash",
            "statusMessage": "Validating command...",
            "once": false
          }
        ]
      }
    ]
  },
  "disableAllHooks": false
}
```

Each event key holds a list of `{matcher, hooks: [...]}` blocks. One matcher can fan out to
multiple handler entries; they run in order.

### Handler Types

**command** (the common case):
```json
{
  "type": "command",
  "command": "script-name | shell-command",
  "args": [],
  "async": false,
  "asyncRewake": false,
  "shell": "bash|powershell",
  "timeout": 600,
  "if": "Bash(git *)",
  "statusMessage": "Running..."
}
```
- **Exec form** (`args` present): command resolved on PATH, spawned directly — no shell, no
  tokenization, path placeholders substituted as plain text. Prefer this when the command has no
  pipes/redirects — it avoids shell-quoting bugs entirely.
- **Shell form** (`args` absent): command passed to a shell with tokenization, pipes, variable
  expansion. Needed for pipelines like the `jq | case` pattern in this repo's PostToolUse gofmt
  hook.

**http**: `{"type": "http", "url": "...", "headers": {...}, "allowedEnvVars": [...], "timeout": 600}`

**mcp_tool**: `{"type": "mcp_tool", "server": "...", "tool": "...", "input": {...}, "timeout": 600}`

**prompt**: `{"type": "prompt", "prompt": "... $ARGUMENTS", "model": "claude-opus-5", "timeout": 30}`

**agent**: `{"type": "agent", "prompt": "... $ARGUMENTS", "timeout": 60}`

### Fields Common to All Handler Types

| Field | Required | Description |
|-------|----------|--------------|
| `type` | yes | `command`, `http`, `mcp_tool`, `prompt`, `agent` |
| `if` | no | Permission-rule filter, tool events only: `Bash(git *)`, `Edit(*.ts)` |
| `timeout` | no | Seconds before cancel. Defaults: 600 (command/http/mcp_tool), 30 (prompt), 60 (agent) |
| `statusMessage` | no | Spinner text while running |
| `once` | no | Run once per session then remove (skill/agent frontmatter only) |

### Path Placeholders

`${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}` — usable in `command` and
`args`, and also exported as env vars on the spawned process. Always prefer `${CLAUDE_PROJECT_DIR}`
over a hardcoded absolute path so the hook survives being cloned to a different machine.

### Bash `if` Matching Rules

`if: "Bash(...)"` filters which Bash invocations even reach the hook, before your script runs:

| Pattern | Command | Matches? | Why |
|---------|---------|----------|-----|
| `Bash(git *)` | `FOO=bar git push` | Yes | Leading assignments stripped |
| `Bash(git *)` | `npm test && git push` | Yes | Each subcommand checked |
| `Bash(rm *)` | `echo $(rm -rf /)` | Yes | Subcommands in `$()` checked |
| `Bash(rm *)` | `echo $(date)` | No | No subcommand matches |
| `Bash(git push *)` | `echo $(date)` | Yes | Complex patterns run anyway (checked in full) |

## Security Best Practices

1. Hook output is capped at 10,000 characters (excess saved to a file).
2. Hooks run without a controlling terminal — use `terminalSequence` (OSC 0/1/2/9/99/777 or BEL
   only) if you need to poke the terminal directly.
3. Use exit 2 for blocking, never exit 1 (silently non-blocking) when the intent is to block.
4. Hook stdout must be *only* the JSON object on exit 0 — no shell profile/login banners leaking
   into stdout, or Claude Code will fail to parse it.
5. Identical handlers (same command/URL) are deduplicated automatically.
6. `allowManagedHooksOnly` (org policy) can block user/project/plugin hooks organization-wide —
   if a hook mysteriously never fires, check whether that's set.
