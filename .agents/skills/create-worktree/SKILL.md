---
name: create-worktree
description: Use whenever the user asks to "create a worktree", "make a worktree", "start a worktree for X", "set up a worktree", or wants a git worktree created for a branch. Similar to the branch skill but creates a git worktree (either attached to a new or existing branch) in an appropriate location, resolves base, fetches fresh, and verifies the worktree is ready.
---

# Create Worktree Skill

Creates a git worktree following trunk-first flow and repo conventions. Mirrors the branch skill's safety guards while producing a usable worktree directory.

## When to use
- User wants to work in an isolated worktree
- "create worktree for issue #N", "make worktree for feature X"
- Need a separate checkout without affecting main working tree

## Inputs
Optional argument: explicit worktree name/path hint, branch name, work description, or issue reference (#123/URL/title). If omitted, derive from current context.

## Safety guards
- Never delete or recreate an existing worktree; if target exists, report and suggest using it
- Never base off a stale local base branch; fetch to keep fresh
- Flag dirty working tree in current repo (inform user) but don't block unless specified
- Avoid placing worktrees in restricted dirs; prefer sibling of repo or /tmp/claude-*/ paths consistent with environment

## Steps

1) **Resolve repo context**
- Confirm we're in a git repo
- Identify default branch (usually `main` via `git symbolic-ref refs/remotes/origin/HEAD` or `git remote show origin`)
- Fetch origin to ensure base is fresh

2) **Determine branch and worktree path**
- Derive short kebab-case branch name from input if creating new branch (Conventional-Commit style orientation: `feat/`, `fix/`, `chore/`, etc. based on description)
- Choose worktree path: if user specified absolute/path, use it; else prefer `../<repo>-<suffix>` or `/tmp/claude-<uid>/-workspaces-<repo>/wt-<suffix>` style matching existing worktrees in this env
- Ensure parent dir exists; avoid clobbering existing worktree/dir

3) **Create worktree**
- If branch exists remotely or locally: create worktree attached to that branch (`git worktree add <path> <branch>`)
- If creating new branch: create from fresh base (`git worktree add -b <branch> <path> <base>`) where base is default branch

4) **Verify**
- List worktrees and show path/branch/HEAD
- Provide commands to cd into worktree and next steps

5) **Report**
Return: worktree path, branch, base, and verification output. Also note any warnings (dirty tree, existing worktree, etc.)

## Implementation
Use shell commands via `functions.shell`. Prefer dedicated git worktree commands. Do not force operations.

Example:
```bash
git fetch origin
base=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@origin/@@')
branch=feat/my-change
path=../infra-terraform-my-change
git worktree add -b "$branch" "$path" "$base"
git worktree list --porcelain | grep -A1 "worktree $path" || true
```

But adjust to environment constraints (permissions) and existing naming.