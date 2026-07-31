#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
# shellcheck disable=SC1091
source "$repo/Config/ToolVersions.env"
tracked="$repo/TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb"
proto_root="$repo/References/TiebaLite-Android/app/src/main/protos"
text_fixture="$repo/scripts/fixtures/personalized_response.textproto"
jar="${TIEBALITE_PROTOBUF_JAVA_JAR:-$repo/.build/FixtureTools/protobuf-java-$EXPECTED_PROTOBUF_JAVA_VERSION.jar}"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-verify-jvm-fixture.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

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

protoc \
  --proto_path="$proto_root" \
  --encode=tieba.PersonalizedResponse \
  Personalized.proto \
  < "$text_fixture" \
  > "$temporary_root/protoc.pb"
cmp "$temporary_root/protoc.pb" "$tracked"

"$repo/scripts/generate_personalized_fixture.sh" --output "$temporary_root/first.pb"
"$repo/scripts/generate_personalized_fixture.sh" --output "$temporary_root/second.pb"
cmp "$temporary_root/first.pb" "$temporary_root/second.pb"
cmp "$temporary_root/first.pb" "$tracked"
printf 'OK: two JVM fixture generations and tracked bytes are identical.\n'

printf 'OK: independent protoc encoding matches the tracked fixture.\n'
