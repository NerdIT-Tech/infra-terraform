---
name: hook-creator
description: Write, wire, and debug native Claude Code hooks (command/http/mcp_tool/prompt/agent handlers registered under the "hooks" key in .claude/settings.json) -- e.g. blocking a dangerous Bash command, auto-formatting or building a file after every edit, injecting context before a prompt is processed, or gating on Stop/SessionStart/PreCompact. Use this whenever the user wants Claude Code itself (not application code) to run a script automatically around tool calls, prompts, or session lifecycle events -- phrases like "add a hook that...", "run X after every edit", "block Claude from running Y", "make Claude always do Z before/after W", or direct mentions of PreToolUse/PostToolUse/UserPromptSubmit/Stop/SessionStart/matcher/settings.json hooks. Covers the JSON stdin schema, exit-code semantics (0/1/2), the JSON output schema (permissionDecision, decision, additionalContext, etc.), matcher syntax, and settings.json wiring -- ground truth pulled from the official hooks reference, not guessed. Don't use this for the hookify plugin's markdown rule DSL (.claude/hookify.*.local.md) -- that's a separate, simpler pattern-matching layer; point there instead if the user just wants a quick regex-triggered warning rather than a real script with programmatic access to the event payload.
---

# Developing Claude Code Hooks

A hook is a script (or HTTP/MCP/prompt/agent call) that Claude Code's harness invokes around a
specific event -- before/after a tool call, at prompt submission, at session start/end, and many
more. The harness always talks to a command hook the same way: it writes a JSON payload to your
script's stdin, and reads your script's exit code and stdout back. Everything else -- what fields
are in the payload, what the exit code means, what JSON you're allowed to print -- follows from
which event you're hooking.

Full field-by-field schemas live in `references/hooks-reference.md`. Read it before wiring
anything nonstandard; this file only carries the shape of the workflow and the parts you'll need
almost every time.

## Workflow

1. **Pick the event.** Ask: *when* does this need to run? "Before a tool executes, with the power
   to block it" is `PreToolUse`. "After a file edit succeeds, to reformat or rebuild" is
   `PostToolUse`. "Before Claude reads the user's message" is `UserPromptSubmit`. "When Claude
   is about to stop responding" is `Stop`. The reference's event table has the full list --
   skim it rather than guessing; there are ~28 events and several (`PostToolUseFailure`,
   `TaskCompleted`, `ConfigChange`, ...) are easy to miss.

2. **Pick the matcher.** Matchers filter *which* occurrences of that event fire the hook -- a tool
   name for `PreToolUse`/`PostToolUse` (`Bash`, `Edit|Write`, `mcp__memory__.*`), a session source
   for `SessionStart`, an agent type for `SubagentStop`, etc. What the matcher compares against is
   event-specific -- check the table in the reference rather than assuming it's always a tool name.
   `"*"`/`""`/omitted matches everything.

3. **Write the script**, starting from `assets/command_hook_template.py` (or the shell-script
   equivalent). Every command hook does the same three things:
   - Read and `json.load` stdin. All events carry `session_id`, `cwd`, `hook_event_name`, plus
     event-specific fields (`tool_name`/`tool_input` for tool events, `prompt` for
     `UserPromptSubmit`, ...).
   - Decide what to do with the event.
   - Communicate the decision via **exit code**, not just stdout:
     - `exit 0` -- success. Only on exit 0 does Claude Code parse stdout as JSON.
     - `exit 2` -- blocking. Stderr is shown to Claude as the reason; whether "blocking" means
       "the tool doesn't run" or "the turn doesn't end" depends on the event (table in the
       reference). Use this, not `exit 1`, whenever you actually want to block something --
       `exit 1` is silently non-blocking and a common mistake.
     - Any other exit code -- non-blocking error, execution continues.

   For a `PreToolUse`-style allow/deny/ask decision that doesn't need to block via stderr, exit 0
   and print `hookSpecificOutput.permissionDecision` instead (see template). Don't invent your own
   top-level fields -- `permissionDecision` (inside `hookSpecificOutput`) is the field that's
   actually read for tool-permission events; the older top-level `decision` field means something
   different and doesn't apply everywhere.

   If you have nothing to say, exit 0 with empty/no stdout -- that's a no-op, not an implicit deny.
   Don't wrap a no-op branch in a JSON object with empty strings; just skip printing.

4. **Test the script directly before wiring it.** A command hook is just a stdin/stdout program --
   run it by hand first:
   ```bash
   echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
     | python3 .claude/hooks/your-hook.py; echo "exit=$?"
   ```
   This catches JSON-shape bugs and exit-code mistakes in seconds, without needing a live Claude
   Code session and a matching tool call to trigger it. Iterate here before touching
   `settings.json`.

5. **Wire it into `.claude/settings.json`** (project-shared) or `.claude/settings.local.json`
   (personal, gitignored) under `hooks.<EventName>`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/your-hook.py", "timeout": 10 }
           ]
         }
       ]
     }
   }
   ```
   **Before you write this block, check the `command` field for a hardcoded absolute path
   (`/workspaces/...`, `/home/...`, `/Users/...`) and replace it with `${CLAUDE_PROJECT_DIR}`.**
   This is an easy slip because the manual stdin test in step 4 works identically either way --
   an absolute path only breaks once the hook is cloned to, or run from, a different machine, so
   nothing in your own testing loop will ever catch it. `${CLAUDE_PROJECT_DIR}` is the one thing
   in this step that isn't optional. Add a `timeout` (seconds) if the default (600s for command
   hooks) is too generous for a script that should fail fast.

6. **Re-test end to end** by actually triggering the event in a live session (e.g. run the Bash
   command the hook should block) rather than trusting the manual stdin test alone -- matcher
   syntax and settings.json placement are the two things the stdin test can't catch.

## Choosing shell form vs. exec form for `command`

- **Exec form** (`args: []` present): the command is resolved on PATH and spawned directly -- no
  shell, no tokenization, no pipes. Prefer this for a single script invocation; it sidesteps
  shell-quoting bugs entirely.
- **Shell form** (`args` omitted, everything in `command` as one string): needed the moment you
  want pipes or command chaining, e.g. this repo's PostToolUse gofmt hook:
  `jq -r '...' | { read -r f; case "$f" in *.go) gofmt -s -w "$f" ;; esac; }`.

## Common patterns

- **Block a dangerous command**: `PreToolUse` + `matcher: "Bash"`, inspect
  `tool_input.command`, exit 2 with a stderr explanation (or `permissionDecision: "deny"`) on
  match.
- **Auto-format/build after edits**: `PostToolUse` + `matcher: "Write|Edit|MultiEdit"`, read
  `tool_response.filePath` (or `tool_input.file_path`), run the formatter/build for matching
  extensions. This can't undo the edit (it already happened) -- exit 2 here stops the loop before
  the *next* model call, it doesn't roll back the file.
- **Inject context before Claude sees a prompt**: `UserPromptSubmit`, print
  `{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "..."}}`.
- **Enforce a checklist before Claude stops**: `Stop`, exit 2 with the missing items in stderr to
  force another turn.
- **Redirect a tool to different input** (e.g. redact secrets before Claude reads a file): see
  this repo's `.claude/hooks/redact-pre.py` -- `PreToolUse` on `Read`, exit 0 with
  `hookSpecificOutput.updatedInput` pointing at a sanitized copy.

Live, working examples in this repo: `.claude/hooks/redact-pre.py`, `redact-post.py`, and the
inline `PostToolUse` gofmt/build hooks in `.claude/settings.json`.

## When this isn't the right tool

If the user wants a quick "warn/block when this regex shows up" rule and doesn't need
programmatic access to the full event payload, the `hookify` plugin's markdown-rule DSL
(`.claude/hookify.*.local.md`, see the `writing-hookify-rules` skill) is faster to author and
doesn't require writing a script at all. Reach for a real hook when you need: multi-field
conditions beyond a single regex, side effects (formatting, running a build, calling an API),
`updatedInput`/`additionalContext` injection, or an event hookify doesn't expose.
