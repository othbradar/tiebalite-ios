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
producer="$repo/scripts/fixtures/ThreadContentFixtureGenerator.java"
default_output="$repo/TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb"
output="$default_output"
jar="${TIEBALITE_PROTOBUF_JAVA_JAR:-$repo/.build/FixtureTools/protobuf-java-$EXPECTED_PROTOBUF_JAVA_VERSION.jar}"
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
  'Thread content fixture output'
[[ ! -L "$output" ]] || {
  printf 'ERROR: fixture output is symlinked.\n' >&2
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
[[ "$(javac -version 2>&1)" == "javac $EXPECTED_JAVA_VERSION" ]] || {
  printf 'ERROR: javac %s is required.\n' "$EXPECTED_JAVA_VERSION" >&2
  exit 1
}
[[ -f "$jar" && ! -L "$jar" ]] || {
  printf 'ERROR: run make bootstrap-fixture-tools for protobuf-java %s.\n' \
    "$EXPECTED_PROTOBUF_JAVA_VERSION" >&2
  exit 66
}
actual_jar_sha1="$(shasum "$jar" | awk '{ print $1 }')"
actual_jar_sha256="$(shasum -a 256 "$jar" | awk '{ print $1 }')"
[[ "$actual_jar_sha1" == "$EXPECTED_PROTOBUF_JAVA_SHA1" &&
   "$actual_jar_sha256" == "$EXPECTED_PROTOBUF_JAVA_SHA256" ]] || {
  printf 'ERROR: protobuf-java jar hash mismatch.\n' >&2
  exit 1
}

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-thread-fixture.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT
mkdir -p "$temporary_root/classes" "$(dirname "$output")"
tiebalite_require_safe_output_path \
  "$output_root" \
  "$output" \
  'Thread content fixture output'

protoc \
  --proto_path="$proto_root" \
  --descriptor_set_out="$temporary_root/thread-content.desc" \
  --include_imports \
  ThreadInfo.proto
javac -cp "$jar" -d "$temporary_root/classes" "$producer"
java -cp "$temporary_root/classes:$jar" \
  ThreadContentFixtureGenerator \
  "$temporary_root/thread-content.desc" \
  "$output"

printf 'Generated JVM thread content fixture: %s\n' "$output"
