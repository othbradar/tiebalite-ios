#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

failures=0
protobuf_module_pattern='\b(SwiftProtobuf|GeneratedProtobuf)\b'
package_key_pattern="^[[:space:]]*[\"']?packages[\"']?[[:space:]]*:"
blocked_artifact_pattern='(\.proto|\.pb\.swift|(^|/)Package\.resolved)$'

assert_pattern_detects() {
  local rule="$1"
  local pattern="$2"
  local canary="$3"
  if ! printf '%s\n' "$canary" | rg "$pattern" >/dev/null; then
    printf '\nERROR [%s-canary]\n' "$rule" >&2
    failures=$((failures + 1))
  fi
}

reject_matches() {
  local rule="$1"
  local pattern="$2"
  shift 2

  local output
  output="$(rg -n --glob '*.swift' "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$output" ]]; then
    printf '\nERROR [%s]\n%s\n' "$rule" "$output" >&2
    failures=$((failures + 1))
  fi
}

reject_matches \
  live-tieba-endpoint \
  'https?://(tiebac\.baidu\.com|c\.tieba\.baidu\.com|tieba\.baidu\.com)' \
  App Sources
assert_pattern_detects \
  live-tieba-endpoint \
  'https?://(tiebac\.baidu\.com|c\.tieba\.baidu\.com|tieba\.baidu\.com)' \
  'https://tiebac.baidu.com/example'

reject_matches \
  shared-url-session \
  'URLSession\.shared' \
  App Sources

reject_matches \
  shared-cookie-storage \
  'HTTPCookieStorage\.shared' \
  App Sources

reject_matches \
  shared-credential-storage \
  'URLCredentialStorage\.shared' \
  App Sources
assert_pattern_detects \
  shared-credential-storage \
  'URLCredentialStorage\.shared' \
  'let credentials = URLCredentialStorage.shared'

reject_matches \
  ui-url-session \
  '\bURLSession\b' \
  App Sources/Features Sources/DesignSystem Sources/InteractionKit

reject_matches \
  ui-protobuf-runtime \
  "$protobuf_module_pattern" \
  App Sources/Features Sources/DesignSystem Sources/InteractionKit

reject_matches \
  protobuf-runtime-before-rights-gate \
  "$protobuf_module_pattern" \
  App Sources
assert_pattern_detects \
  protobuf-runtime-before-rights-gate \
  "$protobuf_module_pattern" \
  '@_implementationOnly import SwiftProtobuf'
assert_pattern_detects \
  protobuf-selective-import-before-rights-gate \
  "$protobuf_module_pattern" \
  'import struct SwiftProtobuf.Message'
assert_pattern_detects \
  protobuf-semicolon-import-before-rights-gate \
  "$protobuf_module_pattern" \
  'import SwiftProtobuf;'
assert_pattern_detects \
  protobuf-multiline-import-before-rights-gate \
  "$protobuf_module_pattern" \
  $'import\nSwiftProtobuf'

if ! rg -q 'httpClient: DisabledHTTPClient\(\)' App/AppCompositionRoot.swift; then
  printf '\nERROR [production-transport-must-remain-disabled]\n' >&2
  failures=$((failures + 1))
fi

if rg -q "$package_key_pattern|SwiftProtobuf|GeneratedProtobuf|swift-protobuf" \
  project.yml ||
  rg -q 'XC(Remote|Local)SwiftPackageReference|XCSwiftPackageProductDependency' \
  TiebaLite.xcodeproj/project.pbxproj
then
  printf '\nERROR [protobuf-rights-gate]\n' >&2
  printf '%s\n' \
    'SwiftPM/SwiftProtobuf cannot enter the project while schema rights remain blocked.' \
    >&2
  failures=$((failures + 1))
fi
assert_pattern_detects \
  project-package-gate \
  "$package_key_pattern" \
  '"packages" : { Codec: { path: Vendor/Codec } }'
assert_pattern_detects \
  generated-project-package-gate \
  'XC(Remote|Local)SwiftPackageReference|XCSwiftPackageProductDependency' \
  'isa = XCLocalSwiftPackageReference;'

blocked_proto_artifacts="$(
  rg --files --hidden \
    --glob '!.git/**' \
    --glob '!.build/**' \
    --glob '!Artifacts/**' \
    --glob '!DerivedData/**' \
    --glob '!References/**' \
    --glob '!TiebaLite.xcodeproj/**' \
    --glob '!TiebaLite_iOS_Codex_Prompt_Kit/**' |
    rg "$blocked_artifact_pattern" ||
    true
)"
if [[ -n "$blocked_proto_artifacts" ]]; then
  printf '\nERROR [protobuf-artifact-before-rights-gate]\n%s\n' \
    "$blocked_proto_artifacts" >&2
  failures=$((failures + 1))
fi
assert_pattern_detects \
  protobuf-artifact-before-rights-gate \
  "$blocked_artifact_pattern" \
  'Protos/Fixture.proto'

printf 'Networking isolation summary: %d failure(s).\n' "$failures"
[[ "$failures" -eq 0 ]]
