#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def applicable_chain(repo: Path, directory: Path) -> list[Path]:
    chain: list[Path] = []
    current = directory
    while True:
        override = current / "AGENTS.override.md"
        agents = current / "AGENTS.md"
        if override.is_file():
            chain.append(override)
        elif agents.is_file():
            chain.append(agents)
        if current == repo:
            break
        current = current.parent
    return list(reversed(chain))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=32 * 1024)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    candidate_dirs = {repo}
    for instruction in repo.rglob("AGENTS*.md"):
        if "/References/" in instruction.as_posix():
            continue
        candidate_dirs.add(instruction.parent)

    failures = 0
    for directory in sorted(candidate_dirs):
        chain = applicable_chain(repo, directory)
        total = sum(path.stat().st_size for path in chain)
        relative = directory.relative_to(repo) if directory != repo else Path(".")
        names = " + ".join(str(path.relative_to(repo)) for path in chain)
        status = "OK" if total <= args.limit else "ERROR"
        print(f"{status}: {relative}: {total}/{args.limit} bytes ({names})")
        if total > args.limit:
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
