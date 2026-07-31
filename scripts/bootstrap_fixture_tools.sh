#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
# shellcheck disable=SC1091
source "$repo/Config/ToolVersions.env"
# shellcheck disable=SC1091
source "$repo/scripts/path_safety.sh"

tool_dir="$repo/.build/FixtureTools"
jar="$tool_dir/protobuf-java-$EXPECTED_PROTOBUF_JAVA_VERSION.jar"

tiebalite_require_safe_output_path "$repo" "$tool_dir" 'fixture tool cache'
tiebalite_require_safe_output_path "$repo" "$jar" 'protobuf-java cache'

verify_jar() {
  local candidate="$1"
  local actual_sha1
  local actual_sha256

  [[ -f "$candidate" && ! -L "$candidate" ]] || return 1
  actual_sha1="$(shasum "$candidate" | awk '{ print $1 }')"
  actual_sha256="$(shasum -a 256 "$candidate" | awk '{ print $1 }')"
  [[ "$actual_sha1" == "$EXPECTED_PROTOBUF_JAVA_SHA1" &&
     "$actual_sha256" == "$EXPECTED_PROTOBUF_JAVA_SHA256" ]]
}

if [[ -e "$jar" || -L "$jar" ]]; then
  if verify_jar "$jar"; then
    printf 'OK: protobuf-java %s fixture tool cache is exact.\n' "$EXPECTED_PROTOBUF_JAVA_VERSION"
    exit 0
  fi
  printf '%s\n' 'ERROR: cached protobuf-java jar is symlinked or has the wrong hash.' >&2
  printf '%s\n' 'Remove only that ignored cache file, then rerun this target.' >&2
  exit 1
fi

command -v curl >/dev/null 2>&1 || {
  printf 'ERROR: curl is required to bootstrap fixture tools.\n' >&2
  exit 1
}

mkdir -p "$tool_dir"
tiebalite_require_safe_output_path "$repo" "$tool_dir" 'fixture tool cache'
tiebalite_require_symlink_free_tree "$tool_dir" 'fixture tool cache'

temporary_root="$(mktemp -d "$tool_dir/.bootstrap.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT
download="$temporary_root/protobuf-java.jar"

curl --fail --location --silent --show-error --output "$download" "$PROTOBUF_JAVA_MAVEN_URL"

if ! verify_jar "$download"; then
  printf 'ERROR: downloaded protobuf-java jar failed exact hash checks.\n' >&2
  exit 1
fi

tiebalite_require_safe_output_path "$repo" "$jar" 'protobuf-java cache'
mv "$download" "$jar"
verify_jar "$jar"

printf 'Installed exact protobuf-java %s fixture tool cache.\n' "$EXPECTED_PROTOBUF_JAVA_VERSION"
