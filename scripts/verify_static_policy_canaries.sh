#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
scanner="$repo/scripts/swift_source_policy.sh"
canary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-policy.XXXXXX")"
trap 'rm -rf "$canary_root"' EXIT

failures=0
canary_sequence=0

expect_rejected() {
  local rule_id="$1" relative_path="$2" source="$3"
  local case_root
  local output
  canary_sequence=$((canary_sequence + 1))
  case_root="$canary_root/${rule_id}-${canary_sequence}"
  mkdir -p "$case_root/$(dirname "$relative_path")"
  printf '%s\n' "$source" > "$case_root/$relative_path"

  if output="$("$scanner" --root "$case_root" 2>&1)"; then
    printf 'ERROR: policy canary unexpectedly passed: %s\n' "$rule_id" >&2
    failures=$((failures + 1))
    return
  fi
  if ! printf '%s\n' "$output" | rg -F "ERROR [$rule_id]" >/dev/null; then
    printf 'ERROR: policy canary failed for the wrong reason: %s\n' "$rule_id" >&2
    failures=$((failures + 1))
  fi
}

expect_rejected direct-console App/Bad.swift \
  'func bad() { print("safe-canary") }'
expect_rejected direct-oslog App/Bad.swift \
  'import OSLog; let badLogger = Logger()'
expect_rejected raw-localized-error App/Bad.swift \
  'func bad(_ error: Error) { _ = error.localizedDescription }'
expect_rejected direct-console Sources/Core/Logging/OSDiagnosticsClient.swift \
  'func bad() { print("safe-canary") }'
expect_rejected raw-localized-error Sources/Core/Logging/OSDiagnosticsClient.swift \
  'func bad(_ error: Error) { _ = error.localizedDescription }'
expect_rejected unchecked-sendable App/Bad.swift \
  'struct Bad: @unchecked Sendable {}'
expect_rejected unsafe-nonisolated App/Bad.swift \
  'nonisolated(unsafe) var badValue = 0'
expect_rejected preconcurrency-import App/Bad.swift \
  '@preconcurrency import Foundation'
expect_rejected detached-task App/Bad.swift \
  'func bad() { Task.detached {} }'
expect_rejected shared-singleton App/Bad.swift \
  'final class Bad { static var shared = Bad() }'
expect_rejected direct-task-sleep Tests/Bad.swift \
  'func bad() async throws { try await Task.sleep(for: .seconds(1)) }'
expect_rejected timing-bypass Tests/Bad.swift \
  'func bad() { DispatchQueue.main.asyncAfter(deadline: .now()) {} }'
expect_rejected test-continuous-clock Tests/Bad.swift \
  'let badClock = ContinuousClock()'
expect_rejected test-current-date Tests/Bad.swift \
  'let badDate = Date()'
expect_rejected test-random-uuid Tests/Bad.swift \
  'let badID = UUID()'
expect_rejected test-random-api Tests/Bad.swift \
  'let badValue = Int.random(in: 0...1)'

allowed_root="$canary_root/allowed"
mkdir -p "$allowed_root/App"
mkdir -p "$allowed_root/Sources/Core/Logging"
mkdir -p "$allowed_root/Tests"
printf '%s\n' \
  'struct GoodEvent: Sendable { let safeCount: Int }' \
  > "$allowed_root/App/Good.swift"
printf '%s\n' \
  'import OSLog' \
  'struct OSDiagnosticsClient {' \
  '    let logger = Logger(subsystem: "fixture", category: "safe")' \
  '}' \
  > "$allowed_root/Sources/Core/Logging/OSDiagnosticsClient.swift"
printf '%s\n' \
  'import Foundation' \
  'let fixedDate = Date(timeIntervalSince1970: 0)' \
  > "$allowed_root/Tests/Good.swift"

if ! "$scanner" --root "$allowed_root" >/dev/null; then
  echo "ERROR: approved source-policy canary was rejected." >&2
  failures=$((failures + 1))
fi

if [[ "$failures" -ne 0 ]]; then
  echo "Static policy canaries failed: $failures case(s)." >&2
  exit 1
fi
echo "OK: static source-policy rejection and approval canaries passed."
