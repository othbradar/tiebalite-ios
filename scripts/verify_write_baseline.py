#!/usr/bin/env python3
"""Reject unapproved drift from the user-accepted beta3 writing lifecycle.

Digests/regions were extracted from 4534020d509ea0188dced53cf582fcc775dbb71e.
Local draft persistence and accepted U07 visuals are deliberately outside this
contract. Approved native migration edits are reversed exactly before checking
the original digest; they never silently replace the beta3 baseline.
"""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def check():
    contract = json.loads((ROOT / "Specs/WRITE_BASELINE.json").read_text())
    failures = []
    for entry in contract["entries"]:
        try:
            source = (ROOT / entry["path"]).read_text()
            migration = entry.get("authorizedNativeMigration")
            if migration:
                if not migration.get("evidence") or not migration.get("authorization"):
                    raise ValueError("Missing native migration evidence/authorization")
                for edit in migration["inverseEdits"]:
                    if source.count(edit["from"]) != 1:
                        raise ValueError("Native migration edit does not match exactly once")
                    source = source.replace(edit["from"], edit["to"], 1)
            if "contains" in entry:
                valid = source.count(entry["contains"]) == 1
            else:
                if entry["start"]:
                    source = source[source.index(entry["start"]):]
                if entry["end"]:
                    source = source[:source.index(entry["end"])]
                valid = hashlib.sha256(source.encode()).hexdigest() == entry["sha256"]
            if not valid:
                failures.append(entry["path"])
        except (OSError, ValueError):
            failures.append(entry["path"])
    for path in sorted(set(failures)):
        print(f"WRITE_BASELINE_DRIFT: {path}")
    if failures:
        print("Do not update the baseline without explicit user authorization.")
        return 1
    print(f"WRITE_BASELINE_PASS: {contract['tag']} / {len(contract['entries'])} checks")
    for entry in contract["entries"]:
        if "authorizedNativeMigration" in entry:
            print(f"APPROVED_NATIVE_MIGRATION: {entry['path']} (original digest retained)")
    return 0


if __name__ == "__main__":
    sys.exit(check())
