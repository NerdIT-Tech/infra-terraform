#!/usr/bin/env python3
"""Template for a Claude Code command hook.

Copy this, rename it, and fill in the marked sections. It follows the same
read-stdin -> decide -> print-JSON -> exit shape as every hook in this repo
(.claude/hooks/redact-pre.py, redact-post.py) so behavior stays predictable
across hooks.

Usage while developing: pipe a fake payload at it directly, no wiring needed.
    echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
      | python3 command_hook_template.py

Only after that looks right, wire it into .claude/settings.json.
"""
import json
import sys

# The event this hook is written for. Used only for the required
# hookSpecificOutput.hookEventName field below -- match it to whatever
# event key you register this under in settings.json.
HOOK_EVENT_NAME = "PreToolUse"


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON on stdin: {e}", file=sys.stderr)
        sys.exit(1)  # non-blocking: malformed input shouldn't wedge the session

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    # --- YOUR DECISION LOGIC GOES HERE ---
    # Inspect `data` (or `tool_name` / `tool_input` for tool events) and decide
    # whether to allow, deny, ask, or just pass through. Delete whichever of
    # the branches below you don't need.

    if False:  # replace with your real condition
        # Blocking path: exit 2 puts the reason in front of Claude as an error.
        print("Explain to Claude why this was blocked.", file=sys.stderr)
        sys.exit(2)

    # Non-blocking allow/deny/ask path: exit 0 with hookSpecificOutput.
    # Omit permissionDecision entirely (just exit 0, no stdout) if you have
    # nothing to say -- that's a no-op, not an implicit deny.
    out = {
        "hookSpecificOutput": {
            "hookEventName": HOOK_EVENT_NAME,
            # "permissionDecision": "allow" | "deny" | "ask" | "defer",
            # "permissionDecisionReason": "why",
        }
    }
    print(json.dumps(out))
    sys.exit(0)


if __name__ == "__main__":
    main()
