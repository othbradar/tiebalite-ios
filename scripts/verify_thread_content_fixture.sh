#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
# shellcheck disable=SC1091
source "$repo/Config/ToolVersions.env"
tracked="$repo/TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb"
proto_root="$repo/References/TiebaLite-Android/app/src/main/protos"
text_fixture="$repo/scripts/fixtures/thread_content_response.textproto"
jar="${TIEBALITE_PROTOBUF_JAVA_JAR:-$repo/.build/FixtureTools/protobuf-java-$EXPECTED_PROTOBUF_JAVA_VERSION.jar}"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-verify-thread-fixture.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT
expected_fixture_sha256="d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12"

[[ -f "$jar" && ! -L "$jar" ]] || {
  printf '%s\n' \
    'ERROR: exact protobuf-java fixture tool cache is required.' \
    'Run make bootstrap-fixture-tools, then retry.' >&2
  exit 66
}
actual_jar_sha1="$(shasum "$jar" | awk '{ print $1 }')"
actual_jar_sha256="$(shasum -a 256 "$jar" | awk '{ print $1 }')"
[[ "$actual_jar_sha1" == "$EXPECTED_PROTOBUF_JAVA_SHA1" &&
   "$actual_jar_sha256" == "$EXPECTED_PROTOBUF_JAVA_SHA256" ]] || {
  printf 'ERROR: protobuf-java fixture tool cache hash mismatch.\n' >&2
  exit 1
}
actual_fixture_sha256="$(shasum -a 256 "$tracked" | awk '{ print $1 }')"
[[ "$actual_fixture_sha256" == "$expected_fixture_sha256" ]] || {
  printf 'ERROR: tracked thread fixture hash mismatch.\n' >&2
  exit 1
}

protoc \
  --proto_path="$proto_root" \
  --encode=tieba.ThreadInfo \
  ThreadInfo.proto \
  < "$text_fixture" \
  > "$temporary_root/protoc.pb"
cmp "$temporary_root/protoc.pb" "$tracked"

"$repo/scripts/generate_thread_content_fixture.sh" \
  --output "$temporary_root/first.pb"
"$repo/scripts/generate_thread_content_fixture.sh" \
  --output "$temporary_root/second.pb"
cmp "$temporary_root/first.pb" "$temporary_root/second.pb"
cmp "$temporary_root/first.pb" "$tracked"
printf 'OK: two JVM thread fixture generations match tracked bytes.\n'
printf 'OK: independent protoc thread encoding matches the tracked fixture.\n'
