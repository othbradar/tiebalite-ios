#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

# shellcheck disable=SC1091
source Config/ToolVersions.env

failures=0
warnings=0

require_version() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    printf 'OK: %s %s\n' "$label" "$actual"
  else
    printf 'ERROR: %s version is %s; expected %s.\n' "$label" "$actual" "$expected" >&2
    failures=$((failures + 1))
  fi
}

xcode_output="$(xcodebuild -version)"
xcode_version="$(awk 'NR == 1 { print $2 }' <<<"$xcode_output")"
xcode_build="$(awk 'NR == 2 { print $3 }' <<<"$xcode_output")"
swift_version="$(swift --version | awk 'NR == 1 { print $4 }')"
xcodegen_version="$(xcodegen --version | awk 'NR == 1 { print $2 }')"
swiftlint_version="$(swiftlint version)"

require_version "Xcode" "$EXPECTED_XCODE_VERSION" "$xcode_version"
require_version "Xcode build" "$EXPECTED_XCODE_BUILD" "$xcode_build"
require_version "Swift" "$EXPECTED_SWIFT_VERSION" "$swift_version"
require_version "XcodeGen" "$EXPECTED_XCODEGEN_VERSION" "$xcodegen_version"
require_version "SwiftLint" "$EXPECTED_SWIFTLINT_VERSION" "$swiftlint_version"

if command -v xcbeautify >/dev/null 2>&1; then
  xcbeautify_version="$(xcbeautify --version)"
  if [[ "$xcbeautify_version" == "$EXPECTED_XCBEAUTIFY_VERSION" ]]; then
    printf 'OK: xcbeautify %s\n' "$xcbeautify_version"
  else
    printf 'WARN: xcbeautify version is %s; expected %s. Raw xcodebuild status remains authoritative.\n' \
      "$xcbeautify_version" "$EXPECTED_XCBEAUTIFY_VERSION" >&2
    warnings=$((warnings + 1))
  fi
else
  printf 'WARN: xcbeautify is unavailable; run_xcodebuild.sh will keep raw output.\n' >&2
  warnings=$((warnings + 1))
fi

printf 'Tool-version summary: %d failure(s), %d warning(s).\n' "$failures" "$warnings"
[[ "$failures" -eq 0 ]]
