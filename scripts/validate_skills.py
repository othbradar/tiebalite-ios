#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skills_root = root / ".agents" / "skills"
errors: list[str] = []
seen: dict[str, Path] = {}

if not skills_root.is_dir():
    print(f"ERROR: missing skills directory: {skills_root}", file=sys.stderr)
    raise SystemExit(1)

for skill_file in sorted(skills_root.glob("*/SKILL.md")):
    text = skill_file.read_text(encoding="utf-8")
    match = re.match(r"\A---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not match:
        errors.append(f"{skill_file}: missing YAML frontmatter")
        continue
    frontmatter = match.group(1)
    name_match = re.search(r"^name:\s*(\S.*?)\s*$", frontmatter, re.MULTILINE)
    description_match = re.search(
        r"^description:\s*(\S.*?)\s*$", frontmatter, re.MULTILINE
    )
    if not name_match:
        errors.append(f"{skill_file}: missing name")
        continue
    if not description_match:
        errors.append(f"{skill_file}: missing description")
        continue
    name = name_match.group(1).strip().strip('"\'')
    description = description_match.group(1).strip().strip('"\'')
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
        errors.append(f"{skill_file}: invalid skill name {name!r}")
    if len(description) < 30:
        errors.append(f"{skill_file}: description is too vague")
    if name in seen:
        errors.append(f"duplicate skill name {name!r}: {seen[name]} and {skill_file}")
    seen[name] = skill_file
    metadata = skill_file.parent / "agents" / "openai.yaml"
    if not metadata.is_file():
        errors.append(f"{skill_file.parent}: missing optional-but-required-here agents/openai.yaml")

if not seen:
    errors.append("no skills found")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"OK: validated {len(seen)} repo skill(s): {', '.join(sorted(seen))}")
