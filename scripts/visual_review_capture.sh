#!/usr/bin/env bash
set -euo pipefail

PHASE="${1:?phase required}"
SCREEN="${2:?screen name required}"
UDID="${3:-${IPHONE_SIMULATOR_UDID:-}}"

if [[ -z "$UDID" ]]; then
  echo "Simulator UDID required." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/Artifacts/VisualReview/$PHASE"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_DIR/${STAMP}-${SCREEN}.png"

xcrun simctl io "$UDID" screenshot "$OUT"
echo "$OUT"
