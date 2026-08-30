#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
# shellcheck disable=SC1091
source "$repo/scripts/path_safety.sh"
# shellcheck disable=SC1091
source "$repo/Config/ToolVersions.env"
reference="$repo/References/TiebaLite-Android"
proto_root="$reference/app/src/main/protos"
input="$repo/scripts/fixtures/profile_response.textproto"
default_output="$repo/TestSupport/Fixtures/API/UserProfile/profile_synthetic.pb"
output="$default_output"
expected_reference="5545326b2a8e0d784b2f3dfbcb219c7b121e61c2"

if [[ "${1:-}" == "--output" ]]; then
  [[ $# -eq 2 ]] || { printf 'Usage: %s [--output file]\n' "$0" >&2; exit 64; }
  output="$2"
  [[ "$output" = /* ]] || output="$repo/$output"
elif [[ $# -ne 0 ]]; then
  printf 'Usage: %s [--output file]\n' "$0" >&2
  exit 64
fi

if [[ "$output" != "$default_output" ]]; then
  output_root="${TMPDIR:-/tmp}"
else
  output_root="$repo"
fi
tiebalite_require_safe_output_path \
  "$output_root" \
  "$output" \
  'Profile fixture output'
[[ ! -L "$output" ]] || {
  printf 'ERROR: Profile fixture output is symlinked.\n' >&2
  exit 1
}
[[ "$(git -C "$reference" rev-parse HEAD)" == "$expected_reference" ]] || {
  printf 'ERROR: Android reference revision drifted.\n' >&2
  exit 1
}
[[ -z "$(git -C "$reference" status --porcelain)" ]] || {
  printf 'ERROR: Android reference is dirty.\n' >&2
  exit 1
}
[[ "$(protoc --version)" == "libprotoc $EXPECTED_PROTOC_VERSION" ]] || {
  printf 'ERROR: protoc %s is required.\n' "$EXPECTED_PROTOC_VERSION" >&2
  exit 1
}

mkdir -p "$(dirname "$output")"
protoc \
  --proto_path="$proto_root" \
  --encode=tieba.profile.ProfileResponse \
  Profile/ProfileResponse.proto \
  < "$input" \
  > "$output"

printf 'Generated synthetic Profile fixture: %s\n' "$output"
