#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo"

failures=0
warnings=0

require() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'ERROR: required command not found: %s\n' "$command_name" >&2
    failures=$((failures + 1))
  else
    printf 'OK: %s -> %s\n' "$command_name" "$(command -v "$command_name")"
  fi
}

optional() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'WARN: optional development tool not found: %s\n' "$command_name" >&2
    warnings=$((warnings + 1))
  else
    printf 'OK: %s -> %s\n' "$command_name" "$(command -v "$command_name")"
  fi
}

printf 'Repository: %s\n' "$repo"
printf '\n== Required commands ==\n'
require git
require xcodebuild
require xcrun
require swift
require python3
require rg

printf '\n== Optional project tools ==\n'
optional brew
optional xcodegen
optional swiftlint
optional xcbeautify

printf '\n== Versions ==\n'
sw_vers || true
xcodebuild -version || true
swift --version || true
git --version || true

printf '\n== Git ==\n'
git status --short || true
git submodule status || true

if [[ -d References/TiebaLite-Android ]]; then
  if git -C References/TiebaLite-Android diff --quiet --ignore-submodules -- && \
     git -C References/TiebaLite-Android diff --cached --quiet --ignore-submodules --; then
    printf 'OK: Android reference worktree is clean.\n'
  else
    printf 'ERROR: Android reference submodule has local modifications.\n' >&2
    failures=$((failures + 1))
  fi
  printf 'Android reference commit: '
  git -C References/TiebaLite-Android rev-parse --short=12 HEAD || true
else
  printf 'WARN: References/TiebaLite-Android is missing. Stage 01 cannot run.\n' >&2
  warnings=$((warnings + 1))
fi

printf '\n== Available iOS devices ==\n'
if ! xcrun simctl list devices available | grep -E 'iPhone|iPad' >/dev/null 2>&1; then
  printf 'ERROR: no available iPhone/iPad simulator device found.\n' >&2
  failures=$((failures + 1))
else
  xcrun simctl list devices available | grep -E 'iPhone|iPad' | head -40 || true
fi

printf '\n== Repository instructions and skills ==\n'
if [[ ! -s AGENTS.md ]]; then
  printf 'ERROR: root AGENTS.md missing or empty.\n' >&2
  failures=$((failures + 1))
fi
python3 scripts/check_instruction_size.py || failures=$((failures + 1))
python3 scripts/validate_skills.py || failures=$((failures + 1))

if [[ -d References/TiebaLite-Android ]]; then
  scripts/reference_integrity.sh || failures=$((failures + 1))
fi

while IFS= read -r -d '' script; do
  bash -n "$script" || failures=$((failures + 1))
done < <(find scripts .agents/skills -type f -name '*.sh' -print0 2>/dev/null)

printf '\nSummary: %d failure(s), %d warning(s).\n' "$failures" "$warnings"
[[ "$failures" -eq 0 ]]
