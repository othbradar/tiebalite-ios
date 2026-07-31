#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-verify-protos.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

scripts/generate_protos.sh --output "$temporary_root/first"
scripts/generate_protos.sh --output "$temporary_root/second"

diff -ru "$temporary_root/first" "$temporary_root/second"
diff -ru "$temporary_root/first" Generated/Protobuf

if rg -F "$repo" "$temporary_root/first"; then
  printf 'ERROR: generated output contains an absolute repository path.\n' >&2
  exit 1
fi
if rg -n '\b(import SwiftUI|import UIKit|import GeneratedProtobuf)\b' \
  "$temporary_root/first"; then
  printf 'ERROR: generated output crosses the UI/module boundary.\n' >&2
  exit 1
fi

printf 'OK: two clean Proto generations and tracked output are identical.\n'
