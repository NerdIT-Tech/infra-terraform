#!/usr/bin/env python3
"""Run trigger evaluation for a skill description (OpenCode port).

Tests whether a skill's description causes OpenCode to trigger (load the
skill) for a set of queries. Outputs results as JSON.

OpenCode exposes a skill to the model as its ID + name + description, and the
model loads it by calling the `skill` tool with the path-derived ID. We create
a throwaway project containing the skill under test, run `opencode run` there,
and watch the line-delimited JSON events for a `skill` tool call whose input
ID matches.

Model-agnostic: pass the model you want via --model (provider/model). Unlike
the Claude version there is no auth-env juggling; OpenCode uses its own auth.
"""

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from scripts.utils import parse_skill_md


def find_project_root() -> Path:
    """Return a stable base directory for throwaway eval projects.

    Kept for signature compatibility with run_loop.py. OpenCode discovers
    project skills by walking up from the working directory, so each query is
    run in its own temporary project instead of the user's repo.
    """
    base = Path(tempfile.gettempdir()) / "opencode-skill-eval"
    base.mkdir(parents=True, exist_ok=True)
    return base


def _iter_events(raw_line: str):
    """Yield parsed events from one line of `opencode run --format json` output."""
    line = raw_line.strip()
    if not line:
        return
    try:
        yield json.loads(line)
    except json.JSONDecodeError:
        return


def _matches_skill(event: dict, clean_id: str) -> bool:
    """True if this event is a `skill` tool call for our throwaway skill ID."""
    if event.get("type") != "tool_use":
        return False
    part = event.get("part", {})
    if part.get("tool") != "skill":
        return False
    inp = part.get("state", {}).get("input", {}) or {}
    # input.id is the skill ID OpenCode selected.
    return inp.get("id") == clean_id


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    project_root: str,
    model: str | None = None,
) -> bool:
    """Run a single query and return whether the skill was triggered.

    Writes a minimal SKILL.md (only the metadata matters for triggering) into a
    temporary OpenCode project, then runs `opencode run` and scans JSON events
    for a `skill` tool call selecting that skill.
    """
    clean_id = f"skill-under-test-{uuid.uuid4().hex[:8]}"
    base = Path(tempfile.mkdtemp(prefix="ocskill-", dir=project_root))
    skill_dir = base / ".opencode" / "skills" / clean_id

    try:
        skill_dir.mkdir(parents=True, exist_ok=True)
        indented = "\n  ".join(skill_description.split("\n"))
        (skill_dir / "SKILL.md").write_text(
            f"---\n"
            f"name: {skill_name}\n"
            f"description: |\n"
            f"  {indented}\n"
            f"---\n\n"
            f"# {skill_name}\n\n"
            f"This skill handles: {skill_description}\n"
        )

        # --standalone gives this run a private server rooted at the temp
        # project's cwd, so skill discovery sees ONLY the throwaway skill and
        # the caller's project is never touched. Without it, `opencode run`
        # connects to the shared background service rooted at the real repo.
        cmd = ["opencode", "run", "--standalone", "--format", "json", "--auto"]
        if model:
            cmd.extend(["--model", model])
        cmd.append(query)

        # OpenCode resolves relative paths from the `PWD` env var, not the
        # process working directory. Popen(cwd=...) does not update PWD, so we
        # set it explicitly — otherwise any files the run writes land in the
        # caller's directory instead of the throwaway project.
        env = {**os.environ, "PWD": str(base)}
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            cwd=str(base),
            env=env,
            text=True,
        )

        triggered = False
        start_time = time.time()
        try:
            while time.time() - start_time < timeout:
                if process.poll() is not None:
                    remainder = process.stdout.read()
                    for event in _iter_events(remainder or ""):
                        if _matches_skill(event, clean_id):
                            triggered = True
                    break

                ready, _, _ = select.select([process.stdout], [], [], 1.0)
                if not ready:
                    continue

                line = process.stdout.readline()
                if not line:
                    break
                for event in _iter_events(line):
                    if _matches_skill(event, clean_id):
                        triggered = True
                        return True
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

        return triggered
    finally:
        shutil.rmtree(base, ignore_errors=True)


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    project_root: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
) -> dict:
    """Run the full eval set and return results."""
    results = []

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_to_info = {}
        for item in eval_set:
            for run_idx in range(runs_per_query):
                future = executor.submit(
                    run_single_query,
                    item["query"],
                    skill_name,
                    description,
                    timeout,
                    str(project_root),
                    model,
                )
                future_to_info[future] = (item, run_idx)

        query_triggers: dict[str, list[bool]] = {}
        query_items: dict[str, dict] = {}
        for future in as_completed(future_to_info):
            item, _ = future_to_info[future]
            query = item["query"]
            query_items[query] = item
            if query not in query_triggers:
                query_triggers[query] = []
            try:
                query_triggers[query].append(future.result())
            except Exception as e:
                print(f"Warning: query failed: {e}", file=sys.stderr)
                query_triggers[query].append(False)

    for query, triggers in query_triggers.items():
        item = query_items[query]
        trigger_rate = sum(triggers) / len(triggers)
        should_trigger = item["should_trigger"]
        if should_trigger:
            did_pass = trigger_rate >= trigger_threshold
        else:
            did_pass = trigger_rate < trigger_threshold
        results.append({
            "query": query,
            "should_trigger": should_trigger,
            "trigger_rate": trigger_rate,
            "triggers": sum(triggers),
            "runs": len(triggers),
            "pass": did_pass,
        })

    passed = sum(1 for r in results if r["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": total - passed,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run trigger evaluation for a skill description (OpenCode)")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=10, help="Number of parallel workers")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model to use for opencode run (provider/model; default: OpenCode's configured model)")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, content = parse_skill_md(skill_path)
    description = args.description or original_description
    project_root = find_project_root()

    if args.verbose:
        print(f"Evaluating: {description}", file=sys.stderr)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
    )

    if args.verbose:
        summary = output["summary"]
        print(f"Results: {summary['passed']}/{summary['total']} passed", file=sys.stderr)
        for r in output["results"]:
            status = "PASS" if r["pass"] else "FAIL"
            rate_str = f"{r['triggers']}/{r['runs']}"
            print(f"  [{status}] rate={rate_str} expected={r['should_trigger']}: {r['query'][:70]}", file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
