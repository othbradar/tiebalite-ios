#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
cd "$repo"
mode="${1:-fast}"
case "$mode" in
  fast) exec make quality-fast ;;
  full) exec make quality ;;
  doctor) exec make doctor ;;
  *) echo "usage: $0 [fast|full|doctor]" >&2; exit 64 ;;
esac
