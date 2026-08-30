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
    rg -v \
      '^Sources/Core/TiebaAPI/(FRSPageProtocol|ForumGuideProtocol|PBPageDomainMapper|PBPageProtocol|PersonalizedProtocol|ThreadContentProtoMapper)\.swift:' ||
    true
)"
if [[ -n "$proto_usage" ]]; then
  fail protobuf-core-allowlist "$proto_usage"
fi
for proto_adapter in \
  Sources/Core/TiebaAPI/FRSPageProtocol.swift \
  Sources/Core/TiebaAPI/ForumGuideProtocol.swift \
  Sources/Core/TiebaAPI/PBPageProtocol.swift \
  Sources/Core/TiebaAPI/PersonalizedProtocol.swift \
  Sources/Core/TiebaAPI/ThreadContentProtoMapper.swift
do
  proto_imports="$(
    rg '^import (GeneratedProtobuf|SwiftProtobuf)$' "$proto_adapter" | sort
  )"
  expected_proto_imports="$(
    printf '%s\n' 'import GeneratedProtobuf' 'import SwiftProtobuf'
  )"
  if [[ "$proto_imports" != "$expected_proto_imports" ]]; then
    fail protobuf-core-exact-imports "$proto_adapter: $proto_imports"
  fi
done
pb_page_mapper_imports="$(
  rg '^import (GeneratedProtobuf|SwiftProtobuf)$' \
    Sources/Core/TiebaAPI/PBPageDomainMapper.swift | sort
)"
if [[ "$pb_page_mapper_imports" != 'import GeneratedProtobuf' ]]; then
  fail protobuf-domain-mapper-exact-imports "$pb_page_mapper_imports"
fi

reject_swift_matches \
  thread-content-domain-leak \
  '^import (SwiftUI|UIKit|GeneratedProtobuf|SwiftProtobuf)$|\bTieba_[A-Za-z0-9_]+\b' \
  Sources/Core/Models/ThreadContent.swift
reject_swift_matches \
  thread-content-mapper-side-effect \
  '@MainActor|\b(URLSession|HTTPClient|HTTPRequest|Endpoint|FileManager|UserDefaults|HTTPCookieStorage|Keychain)\b|SecItem(Add|CopyMatching|Update|Delete)' \
  Sources/Core/TiebaAPI/ThreadContentProtoMapper.swift
reject_swift_matches \
  pb-page-domain-mapper-side-effect \
  '@MainActor|\b(URLSession|HTTPClient|HTTPRequest|Endpoint|FileManager|UserDefaults|HTTPCookieStorage|Keychain)\b|SecItem(Add|CopyMatching|Update|Delete)' \
  Sources/Core/TiebaAPI/PBPageDomainMapper.swift
reject_swift_matches \
  thread-reader-protobuf-leak \
  '\b(SwiftProtobuf|GeneratedProtobuf|Tieba_[A-Za-z0-9_]+)\b' \
  Sources/Features/ThreadReader
reject_swift_matches \
  followed-forums-network-access \
  '\b(URLSession|HTTPClient|HTTPRequest|Endpoint)\b' \
  Sources/Features/FollowedForums
reject_swift_matches \
  followed-forums-credential-access \
  '\b(SessionAuthorization|SessionCredential|Keychain)\b|BDUSS|STOKEN' \
  Sources/Features/FollowedForums
reject_swift_matches \
  followed-forums-interaction-leak \
  '\b(PagerContainer|MediaViewer|DragGesture)\b|\.gesture[[:space:]]*\(|\.overlay[[:space:]]*\(|\.sheet[[:space:]]*\(|\.fullScreenCover[[:space:]]*\(|\.animation[[:space:]]*\(|withAnimation[[:space:]]*\(' \
  Sources/Features/FollowedForums
reject_swift_matches \
  forum-home-network-access \
  '\b(URLSession|HTTPClient|HTTPRequest|Endpoint)\b' \
  Sources/Features/Forum
reject_swift_matches \
  forum-home-credential-access \
  '\b(SessionAuthorization|SessionCredential|Keychain)\b|BDUSS|STOKEN' \
  Sources/Features/Forum
reject_swift_matches \
  forum-home-interaction-leak \
  '\b(PagerContainer|MediaViewer|DragGesture)\b|\.gesture[[:space:]]*\(|\.overlay[[:space:]]*\(|\.sheet[[:space:]]*\(|\.fullScreenCover[[:space:]]*\(|\.animation[[:space:]]*\(|withAnimation[[:space:]]*\(' \
  Sources/Features/Forum
reject_swift_matches \
  search-network-access \
  '\b(URLSession|HTTPClient|HTTPRequest|Endpoint)\b' \
  Sources/Features/Search
reject_swift_matches \
  search-credential-access \
  '\b(SessionAuthorization|SessionCredential|Keychain)\b|BDUSS|STOKEN|Cookie' \
  Sources/Features/Search
reject_swift_matches \
  search-interaction-leak \
  '\b(PagerContainer|MediaViewer|DragGesture)\b|\.gesture[[:space:]]*\(|\.overlay[[:space:]]*\(|\.sheet[[:space:]]*\(|\.fullScreenCover[[:space:]]*\(|\.animation[[:space:]]*\(|withAnimation[[:space:]]*\(' \
  Sources/Features/Search
reject_swift_matches \
  thread-reader-network-access \
  '\b(URLSession|HTTPClient|HTTPRequest|Endpoint)\b' \
  Sources/Features/ThreadReader
reject_swift_matches \
  thread-reader-pager-media-viewer \
  '\b(PagerContainer|MediaViewer|UIPageViewController)\b|\.tabViewStyle[[:space:]]*\([[:space:]]*\.page' \
  Sources/Features/ThreadReader
reject_swift_matches \
  thread-reader-gesture \
  '\bDragGesture\b|\.gesture[[:space:]]*\(|\.simultaneousGesture[[:space:]]*\(|\.highPriorityGesture[[:space:]]*\(' \
  Sources/Features/ThreadReader
reject_swift_matches \
  thread-reader-presentation-overlay \
  '\.overlay[[:space:]]*\(|\.sheet[[:space:]]*\(|\.fullScreenCover[[:space:]]*\(' \
  Sources/Features/ThreadReader
reject_swift_matches \
  thread-reader-custom-animation \
  '\.animation[[:space:]]*\(|withAnimation[[:space:]]*\(' \
  Sources/Features/ThreadReader
reject_swift_matches \
  stage08-full-thread-screen \
  '\b(ThreadScreen|ThreadReaderScreen|ThreadRepository|ThreadEndpoint)\b' \
  App Sources/Features/ThreadReader

production_block="$(
  sed -n '/static func production()/,/^    }/p' App/AppCompositionRoot.swift
)"
for production_requirement in \
  'readingDataSourceMode: \.live' \
  'URLSessionHTTPClient\.production\(\)' \
  'imageLoader: DisabledImageLoader\(\)'
do
  if ! printf '%s\n' "$production_block" |
    rg -q "$production_requirement"; then
    fail production-live-composition "$production_requirement"
  fi
done
if printf '%s\n' "$production_block" |
  rg -q 'DisabledHTTPClient|FixtureFollowedForumsRepository|FixtureRecommendationRepository|FixtureThreadReaderRepository|FixtureReadingImageLoader'; then
  fail production-live-composition-leak "$production_block"
fi
if ! rg -q \
  'followedForumsRepository =.*LiveFollowedForumsRepository|LiveFollowedForumsRepository\(' \
  App/AppCompositionRoot.swift; then
  fail production-followed-forums-live-after-runtime-evidence
fi
if rg -q \
  'followedForumsRepository =.*EvidenceBlockedFollowedForumsRepository|EvidenceBlockedFollowedForumsRepository\(\)' \
  App/AppCompositionRoot.swift; then
  fail production-followed-forums-evidence-regression
fi
if ! rg -q \
  'recommendationRepository =.*LiveRecommendationRepository|LiveRecommendationRepository\(' \
  App/AppCompositionRoot.swift; then
  fail production-recommendations-live-after-runtime-evidence
fi
if rg -q \
  'recommendationRepository =.*EvidenceBlockedRecommendationRepository|EvidenceBlockedRecommendationRepository\(\)' \
  App/AppCompositionRoot.swift; then
  fail production-recommendations-evidence-regression
fi
if ! rg -q \
  'forumHomeRepository = LiveForumHomeRepository' \
  App/AppCompositionRoot.swift; then
  fail production-forum-home-live-after-runtime-evidence
fi
if rg -q \
  'forumHomeRepository = EvidenceBlockedForumHomeRepository' \
  App/AppCompositionRoot.swift; then
  fail production-forum-home-evidence-regression
fi
if ! rg -q \
  'searchRepository = LiveSearchRepository' \
  App/AppCompositionRoot.swift; then
  fail production-search-live-after-runtime-evidence
fi
if ! rg -q 'readingDataSourceMode: \.fixture' \
  TestSupport/LaunchScenarios/LaunchScenarioFactory.swift; then
  fail ui-scenario-fixture-mode
fi
scenario_live_usage="$(
  rg -n '\.live\b|URLSessionHTTPClient|LiveFollowedForumsRepository|LiveForumHomeRepository|LiveRecommendationRepository|LiveSearchRepository|LiveThreadReaderRepository|tiebac\.baidu\.com|tieba\.baidu\.com' \
    TestSupport/LaunchScenarios 2>/dev/null || true
)"
if [[ -n "$scenario_live_usage" ]]; then
  fail ui-scenario-live-reachability "$scenario_live_usage"
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
if [[ "$generated_count" -ne 156 ]]; then
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
    'Generated/Protobuf/App.pb.swift' \
    'Generated/Protobuf/CommonReq.pb.swift' \
    'Generated/Protobuf/CommonRequest.pb.swift' \
    'Generated/Protobuf/ForumGuide/LikeForum.pb.swift' \
    'Generated/Protobuf/FrsPage/ForumInfo.pb.swift' \
    'Generated/Protobuf/FrsPage/FrsPage.pb.swift' \
    'Generated/Protobuf/FrsPage/HeadImgs.pb.swift' \
    'Generated/Protobuf/FrsPage/SignInfo.pb.swift' \
    'Generated/Protobuf/GoodsInfo.pb.swift' \
    'Generated/Protobuf/Item.pb.swift' \
    'Generated/Protobuf/OriginThreadInfo.pb.swift' \
    'Generated/Protobuf/PbContent.pb.swift' \
    'Generated/Protobuf/PbPage/PbPageRequestData.pb.swift' \
    'Generated/Protobuf/PbPage/PbPageResponseData.pb.swift' \
    'Generated/Protobuf/Personalized.pb.swift' \
    'Generated/Protobuf/Post.pb.swift' \
    'Generated/Protobuf/SubPostList.pb.swift' \
    'Generated/Protobuf/TPointPost.pb.swift' \
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
      "$unchecked_count" -ne 24 ]]; then
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
thread_fixture_hash="$(
  shasum -a 256 \
    TestSupport/Fixtures/API/ThreadContent/thread_content_cross_language.pb |
    awk '{ print $1 }'
)"
if [[ "$thread_fixture_hash" != \
  'd37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12' ]]; then
  fail thread-content-cross-language-fixture-hash "$thread_fixture_hash"
fi
thread_manifest_result=""
if ! thread_manifest_result="$(
  python3 - TestSupport/Fixtures/manifest.json <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)

fixture_id = "thread-content.first-post.cross-language"
matches = [
    entry for entry in manifest.get("entries", [])
    if entry.get("id") == fixture_id
]
expected = {
    "format": "protobuf",
    "path": "API/ThreadContent/thread_content_cross_language.pb",
    "sanitized": True,
    "sha256": "d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12",
    "source": "crossLanguageGenerated",
}
if len(matches) != 1:
    print(f"{fixture_id}: expected one entry, found {len(matches)}")
    raise SystemExit(1)
actual = {key: matches[0].get(key) for key in expected}
if actual != expected:
    print(f"{fixture_id}: {actual!r}")
    raise SystemExit(1)
PY
)"; then
  fail thread-content-cross-language-fixture-manifest "$thread_manifest_result"
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
assert_pattern_detects \
  thread-reader-pager-media-viewer \
  '\b(PagerContainer|MediaViewer|UIPageViewController)\b|\.tabViewStyle[[:space:]]*\([[:space:]]*\.page' \
  'let viewer = MediaViewer()'

for output_script in \
  scripts/generate_protos.sh \
  scripts/generate_personalized_fixture.sh \
  scripts/generate_thread_content_fixture.sh
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
if TIEBALITE_PROTOBUF_JAVA_JAR="$safety_root/missing.jar" \
  scripts/verify_thread_content_fixture.sh >/dev/null 2>&1; then
  fail missing-thread-jvm-fixture-tool-must-fail
fi

printf 'Networking isolation summary: %d failure(s).\n' "$failures"
[[ "$failures" -eq 0 ]]
