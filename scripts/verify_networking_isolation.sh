#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
cd "$repo"
# shellcheck disable=SC1091
source "$repo/scripts/path_safety.sh"

failures=0

fail() {
  local rule="$1"
  local detail="${2:-}"
  printf '\nERROR [%s]\n' "$rule" >&2
  if [[ -n "$detail" ]]; then
    printf '%s\n' "$detail" >&2
  fi
  failures=$((failures + 1))
}

assert_pattern_detects() {
  local rule="$1"
  local pattern="$2"
  local canary="$3"
  if ! printf '%s\n' "$canary" | rg "$pattern" >/dev/null; then
    fail "$rule-canary"
  fi
}

reject_swift_matches() {
  local rule="$1"
  local pattern="$2"
  shift 2
  local output
  output="$(rg -n --glob '*.swift' "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$output" ]]; then
    fail "$rule" "$output"
  fi
}

reject_swift_matches \
  live-tieba-endpoint \
  'https?://(tiebac\.baidu\.com|c\.tieba\.baidu\.com|tieba\.baidu\.com)' \
  App Sources
assert_pattern_detects \
  live-tieba-endpoint \
  'https?://(tiebac\.baidu\.com|c\.tieba\.baidu\.com|tieba\.baidu\.com)' \
  'https://tiebac.baidu.com/example'

reject_swift_matches shared-url-session 'URLSession\.shared' App Sources
reject_swift_matches shared-cookie-storage 'HTTPCookieStorage\.shared' App Sources
reject_swift_matches \
  shared-credential-storage \
  'URLCredentialStorage\.shared' \
  App Sources
reject_swift_matches \
  ui-url-session \
  '\bURLSession\b' \
  App Sources/Features Sources/DesignSystem Sources/InteractionKit
reject_swift_matches \
  ui-protobuf-runtime \
  '\b(SwiftProtobuf|GeneratedProtobuf|Tieba_[A-Za-z0-9_]+)\b' \
  App Sources/Features Sources/DesignSystem Sources/InteractionKit

proto_usage="$(
  rg -n --glob '*.swift' \
    '\b(SwiftProtobuf|GeneratedProtobuf|Tieba_[A-Za-z0-9_]+)\b' \
    App Sources 2>/dev/null |
    rg -v '^Sources/Core/TiebaAPI/PersonalizedProtocol\.swift:' ||
    true
)"
if [[ -n "$proto_usage" ]]; then
  fail protobuf-core-allowlist "$proto_usage"
fi
proto_import_count="$(
  rg -n '^import (GeneratedProtobuf|SwiftProtobuf)$' \
    Sources/Core/TiebaAPI/PersonalizedProtocol.swift | wc -l | tr -d ' '
)"
if [[ "$proto_import_count" -ne 2 ]]; then
  fail protobuf-core-import-count "$proto_import_count"
fi

if ! rg -q 'httpClient: DisabledHTTPClient\(\)' App/AppCompositionRoot.swift; then
  fail production-transport-must-remain-disabled
fi

package_block="$(sed -n '/^packages:/,/^fileGroups:/p' project.yml)"
expected_package_block="$(
  printf '%s\n' \
    'packages:' \
    '  SwiftProtobuf:' \
    '    url: https://github.com/apple/swift-protobuf.git' \
    '    exactVersion: 1.38.1' \
    '' \
    'fileGroups:'
)"
if [[ "$package_block" != "$expected_package_block" ]]; then
  fail project-package-lock "$package_block"
fi
if rg -n \
  'XCLocalSwiftPackageReference|kind = (branch|revision|upToNext|upToNextMajor|upToNextMinor)' \
  TiebaLite.xcodeproj/project.pbxproj >/dev/null; then
  fail generated-project-package-selector
fi
for expectation in \
  'isa = XCRemoteSwiftPackageReference;|1' \
  'repositoryURL = "https://github.com/apple/swift-protobuf.git";|1' \
  'kind = exactVersion;|1' \
  'version = 1.38.1;|1' \
  'isa = XCSwiftPackageProductDependency;|3' \
  'productName = SwiftProtobuf;|3'
do
  pattern="${expectation%|*}"
  expected_count="${expectation##*|}"
  actual_count="$(rg -c "$pattern" TiebaLite.xcodeproj/project.pbxproj || true)"
  actual_count="${actual_count:-0}"
  if [[ "$actual_count" -ne "$expected_count" ]]; then
    fail generated-project-package-count "$pattern=$actual_count"
  fi
done
if ! rg -q 'productReference = .*libGeneratedProtobuf\.a' \
  TiebaLite.xcodeproj/project.pbxproj; then
  fail generated-module-static-library
fi

proto_outside_reference="$(
  rg --files --hidden \
    --glob '!.git/**' \
    --glob '!.build/**' \
    --glob '!Artifacts/**' \
    --glob '!References/**' \
    --glob '!TiebaLite.xcodeproj/**' \
    --glob '!TiebaLite_iOS_Codex_Prompt_Kit/**' |
    rg '\.proto$' ||
    true
)"
if [[ -n "$proto_outside_reference" ]]; then
  fail copied-proto-artifact "$proto_outside_reference"
fi
generated_outside_allowlist="$(
  rg --files --hidden \
    --glob '!.git/**' \
    --glob '!.build/**' \
    --glob '!Artifacts/**' \
    --glob '!References/**' \
    --glob '!TiebaLite.xcodeproj/**' \
    --glob '!TiebaLite_iOS_Codex_Prompt_Kit/**' |
    rg '\.pb\.swift$' |
    rg -v '^Generated/Protobuf/' ||
    true
)"
if [[ -n "$generated_outside_allowlist" ]]; then
  fail generated-protobuf-location "$generated_outside_allowlist"
fi
generated_count="$(find Generated/Protobuf -type f -name '*.pb.swift' | wc -l | tr -d ' ')"
if [[ "$generated_count" -ne 51 ]]; then
  fail generated-protobuf-count "$generated_count"
fi

known_locks="$(
  git ls-files --cached --others --exclude-standard -- '*Package.resolved' | sort
)"
if [[ "$known_locks" != 'Config/SwiftPM/Package.resolved' ]]; then
  fail canonical-package-lock-location "$known_locks"
fi
build_lock_check_count="$(
  rg -c '^scripts/verify_swiftpm_lock\.sh$' scripts/run_xcodebuild.sh || true
)"
last_build_script_line="$(tail -n 1 scripts/run_xcodebuild.sh)"
if [[ "$build_lock_check_count" -ne 2 ||
      "$last_build_script_line" != 'scripts/verify_swiftpm_lock.sh' ]]; then
  fail xcodebuild-package-lock-pre-post-check "$build_lock_check_count"
fi
for resolved_flag in '-onlyUsePackageVersionsFromResolvedFile' '-skipPackageUpdates'; do
  if [[ "$(rg -c --fixed-strings -- "$resolved_flag" scripts/run_xcodebuild.sh)" -ne 1 ]]; then
    fail xcodebuild-resolved-only-flag "$resolved_flag"
  fi
done

unchecked_usage="$(
  rg -n '@unchecked[[:space:]]+Sendable|@preconcurrency[[:space:]]+import' \
    App Sources Tests TestSupport --glob '*.swift' 2>/dev/null ||
    true
)"
if [[ -n "$unchecked_usage" ]]; then
  fail handwritten-concurrency-bypass "$unchecked_usage"
fi
expected_unchecked_files="$(
  printf '%s\n' \
    'Generated/Protobuf/AlaLiveInfo.pb.swift' \
    'Generated/Protobuf/AlaUserInfo.pb.swift' \
    'Generated/Protobuf/CommonRequest.pb.swift' \
    'Generated/Protobuf/Item.pb.swift' \
    'Generated/Protobuf/OriginThreadInfo.pb.swift' \
    'Generated/Protobuf/PbContent.pb.swift' \
    'Generated/Protobuf/Personalized.pb.swift' \
    'Generated/Protobuf/ThreadInfo.pb.swift' \
    'Generated/Protobuf/User.pb.swift' \
    'Generated/Protobuf/ZhiBoInfoTW.pb.swift'
)"
actual_unchecked_files="$(
  rg -l '@unchecked[[:space:]]+Sendable' Generated/Protobuf | sort
)"
unchecked_count="$(
  rg -n '@unchecked[[:space:]]+Sendable' Generated/Protobuf | wc -l | tr -d ' '
)"
if [[ "$actual_unchecked_files" != "$expected_unchecked_files" ||
      "$unchecked_count" -ne 10 ]]; then
  fail generated-unchecked-sendable-allowlist "$actual_unchecked_files"
fi

if rg -n 'n0099' \
  Config/Protobuf scripts/generate_protos.sh Generated/Protobuf >/dev/null; then
  fail forbidden-proto-input-n0099
fi
if rg -n '\b(import SwiftUI|import UIKit|import GeneratedProtobuf)\b' \
  Generated/Protobuf >/dev/null; then
  fail generated-module-ui-boundary
fi

if ! rg -q '^Artifacts/PrivateCaptures/\*\*$' .gitignore; then
  fail private-capture-ignore-rule
fi
if ! git check-ignore -q Artifacts/PrivateCaptures/isolation.canary; then
  fail private-capture-ignore-behavior
fi
tracked_captures="$(git ls-files 'Artifacts/PrivateCaptures/**')"
if [[ -n "$tracked_captures" ]]; then
  fail tracked-private-capture "$tracked_captures"
fi

fixture_hash="$(
  shasum -a 256 \
    TestSupport/Fixtures/API/Recommendations/personalized_cross_language.pb |
    awk '{ print $1 }'
)"
if [[ "$fixture_hash" != \
  '54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a' ]]; then
  fail cross-language-fixture-hash "$fixture_hash"
fi
if ! rg -q '"source": "crossLanguageGenerated"' \
  TestSupport/Fixtures/manifest.json; then
  fail cross-language-fixture-classification
fi

assert_pattern_detects \
  ui-protobuf-runtime \
  '\b(SwiftProtobuf|GeneratedProtobuf|Tieba_[A-Za-z0-9_]+)\b' \
  'import GeneratedProtobuf'
assert_pattern_detects \
  handwritten-concurrency-bypass \
  '@unchecked[[:space:]]+Sendable|@preconcurrency[[:space:]]+import' \
  'struct Unsafe: @unchecked Sendable {}'

for output_script in \
  scripts/generate_protos.sh \
  scripts/generate_personalized_fixture.sh
do
  if ! rg -q 'source "\$repo/scripts/path_safety\.sh"' "$output_script" ||
     ! rg -q 'tiebalite_require_safe_output_path' "$output_script"; then
    fail output-path-safety-wiring "$output_script"
  fi
done
if [[ ! -x scripts/bootstrap_fixture_tools.sh ]]; then
  fail fixture-tool-bootstrap-not-executable
fi
if ! rg -q '^PROTOBUF_JAVA_MAVEN_URL="https://repo\.maven\.apache\.org/maven2/com/google/protobuf/protobuf-java/4\.35\.1/protobuf-java-4\.35\.1\.jar"$' Config/ToolVersions.env; then
  fail fixture-tool-source-lock
fi
if rg -q 'NOTE: exact JVM jar cache absent' scripts/verify_personalized_fixture.sh; then
  fail fixture-verifier-must-not-degrade
fi

safety_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-path-safety.XXXXXX")"
trap 'rm -rf "$safety_root"' EXIT
mkdir -p "$safety_root/root/tree" "$safety_root/outside"
ln -s "$safety_root/outside" "$safety_root/root/linked"
if tiebalite_require_safe_output_path \
  "$safety_root/root" \
  "$safety_root/root/linked/output" \
  'symlink ancestor canary' 2>/dev/null; then
  fail output-path-symlink-ancestor-canary
fi
if tiebalite_require_safe_output_path \
  "$safety_root/root" \
  "$safety_root/root/linked/../escaped" \
  'symlink dot-dot canary' 2>/dev/null; then
  fail output-path-symlink-dot-dot-canary
fi
ln -s "$safety_root/outside/file" "$safety_root/root/tree/output.pb.swift"
if tiebalite_require_symlink_free_tree \
  "$safety_root/root/tree" \
  'symlink tree canary' 2>/dev/null; then
  fail output-tree-symlink-canary
fi
if TIEBALITE_PROTOBUF_JAVA_JAR="$safety_root/missing.jar" \
  scripts/verify_personalized_fixture.sh >/dev/null 2>&1; then
  fail missing-jvm-fixture-tool-must-fail
fi

printf 'Networking isolation summary: %d failure(s).\n' "$failures"
[[ "$failures" -eq 0 ]]
