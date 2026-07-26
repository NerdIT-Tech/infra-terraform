#!/usr/bin/env python3
"""PostToolUse hook: terraform fmt + tflint + Trivy on every .tf write/edit.

Mirrors the checks terraform-pr.yml runs in CI (tflint --recursive from repo
root, trivy config --severity CRITICAL,HIGH), so problems surface locally in
the same turn instead of only on the PR's CI run.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Invalid JSON on stdin: {e}", file=sys.stderr)
        sys.exit(1)  # non-blocking: malformed input shouldn't wedge the session

    tool_response = data.get("tool_response") or {}
    tool_input = data.get("tool_input") or {}
    file_path = tool_response.get("filePath") or tool_input.get("file_path") or ""

    if not file_path.endswith(".tf"):
        sys.exit(0)

    problems = []

    fmt = run(["terraform", "fmt", file_path], cwd=REPO_ROOT)
    if fmt.returncode != 0:
        problems.append("terraform fmt failed:\n" + fmt.stderr.strip())

    if shutil.which("tflint"):
        if not (REPO_ROOT / ".tflint.d").exists():
            run(["tflint", "--init"], cwd=REPO_ROOT)
        lint = run(["tflint", "--recursive"], cwd=REPO_ROOT)
        if lint.returncode != 0:
            problems.append("tflint findings:\n" + (lint.stdout + lint.stderr).strip())
    else:
        print("tflint not found on PATH -- skipping lint check", file=sys.stderr)

    if shutil.which("trivy"):
        scan = run(
            ["trivy", "config", "--severity", "CRITICAL,HIGH", "--exit-code", "1", "."],
            cwd=REPO_ROOT,
        )
        if scan.returncode != 0:
            problems.append("Trivy IaC scan findings:\n" + scan.stdout.strip())
    else:
        print("trivy not found on PATH -- skipping IaC scan (not installed in this devcontainer)", file=sys.stderr)

    if problems:
        print("\n\n".join(problems), file=sys.stderr)
        sys.exit(2)  # blocking: surface findings to Claude so they get fixed now

    sys.exit(0)


if __name__ == "__main__":
    main()
