#!/usr/bin/env python3
"""
Quick validation script for OpenCode skills.

OpenCode's contracts differ from Claude's, so the checks here are looser:
- The skill ID comes from the path, not the frontmatter `name`.
- All frontmatter is optional at runtime, but a `description` is what makes a
  skill discoverable, so we require it for packaging.
- OpenCode documents recommendations (kebab-case ID, name match, description
  length) but does not enforce them; we only warn on those.
"""

import re
import sys
from pathlib import Path

import yaml

ALLOWED_PROPERTIES = {
    "name",
    "description",
    "license",
    "compatibility",
    "allowed-tools",
    "metadata",
    "disable-model-invocation",
}
ID_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def validate_skill(skill_path):
    """Basic validation of an OpenCode skill directory."""
    skill_path = Path(skill_path)

    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        return False, "SKILL.md not found"

    content = skill_md.read_text()

    frontmatter = {}
    if content.startswith("---"):
        match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
        if not match:
            return False, "Invalid frontmatter format"
        try:
            frontmatter = yaml.safe_load(match.group(1)) or {}
        except yaml.YAMLError as e:
            return False, f"Invalid YAML in frontmatter: {e}"
        if not isinstance(frontmatter, dict):
            return False, "Frontmatter must be a YAML dictionary"

    unexpected = set(frontmatter.keys()) - ALLOWED_PROPERTIES
    if unexpected:
        return False, (
            f"Unexpected key(s) in SKILL.md frontmatter: {', '.join(sorted(unexpected))}. "
            f"Allowed properties are: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    description = frontmatter.get("description", "")
    if not isinstance(description, str):
        return False, f"Description must be a string, got {type(description).__name__}"
    if not description.strip():
        return False, "Missing 'description' in frontmatter (skills without one are not discoverable)"

    name = frontmatter.get("name", "")
    if name and not isinstance(name, str):
        return False, f"Name must be a string, got {type(name).__name__}"

    # Warnings only: OpenCode does not enforce these.
    warnings = []
    if len(description) > 1024:
        warnings.append(f"description is {len(description)} chars (recommended max 1024)")
    if not ID_PATTERN.match(skill_path.name):
        warnings.append(f"directory name '{skill_path.name}' is not kebab-case (recommended for the skill ID)")

    message = "Skill is valid!"
    if warnings:
        message += " Warnings: " + "; ".join(warnings)
    return True, message


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)

    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
