#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"
reference="References/TiebaLite-Android"
lock_file="References/TiebaLite-Android.lock"

if [[ ! -d "$reference/.git" && ! -f "$reference/.git" ]]; then
  echo "ERROR: Android reference submodule is missing: $reference" >&2
  exit 1
fi

if ! git -C "$reference" diff --quiet --ignore-submodules -- || \
   ! git -C "$reference" diff --cached --quiet --ignore-submodules --; then
  echo "ERROR: Android reference has local modifications; it is read-only." >&2
  git -C "$reference" status --short >&2 || true
  exit 1
fi

actual="$(git -C "$reference" rev-parse HEAD)"
if [[ -f "$lock_file" ]]; then
  expected="$(awk 'NF && $1 !~ /^#/ { print $1; exit }' "$lock_file")"
  if [[ -z "$expected" ]]; then
    echo "ERROR: $lock_file exists but has no commit SHA." >&2
    exit 1
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Android reference commit differs from lock." >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    echo "Update the lock only in an explicit reference-upgrade task with a new audit." >&2
    exit 1
  fi
  echo "OK: Android reference is clean and locked at $actual"
else
  echo "WARN: $lock_file is missing. Stage 00/01 should create it with the full SHA:" >&2
  echo "$actual  # TiebaLite 4.0-dev audited reference" >&2
fi
