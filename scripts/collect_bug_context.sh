#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
cd "$repo"
output="${1:-Artifacts/bug-context-$(date +%Y%m%d-%H%M%S).txt}"
mkdir -p "$(dirname "$output")"
{
  echo "# Bug context (non-sensitive)"
  date -u '+UTC: %Y-%m-%dT%H:%M:%SZ'
  echo
  echo "## Repository"
  git rev-parse --show-toplevel
  git branch --show-current || true
  git rev-parse HEAD || true
  git status --short || true
  echo
  echo "## Toolchain"
  sw_vers || true
  xcodebuild -version || true
  swift --version || true
  echo
  echo "## Available simulators"
  xcrun simctl list devices available | grep -E 'iPhone|iPad' || true
  echo
  echo "## Relevant static inventory"
  rg -n --glob '*.swift' '\.animation\(|withAnimation\(|DragGesture\(|\.overlay\(|\.sheet\(|fullScreenCover\(' App Sources 2>/dev/null || true
} > "$output"
echo "Wrote $output"
