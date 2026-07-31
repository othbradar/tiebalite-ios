#!/usr/bin/env bash
set -euo pipefail

scan_root=""
if [[ "${1:-}" == "--root" ]]; then
  scan_root="${2:-}"
  shift 2
fi
if [[ $# -ne 0 ]]; then
  echo "usage: $0 [--root PATH]" >&2
  exit 64
fi
if [[ -z "$scan_root" ]]; then
  scan_root="$(git rev-parse --show-toplevel)"
fi
if [[ ! -d "$scan_root" ]]; then
  echo "ERROR: source-policy root does not exist." >&2
  exit 66
fi
cd "$scan_root"

all_roots=()
for candidate in App Sources TestSupport Tests UITests; do
  [[ -d "$candidate" ]] && all_roots+=("$candidate")
done
if [[ ${#all_roots[@]} -eq 0 ]]; then
  echo "OK: no Swift source roots; source policy skipped."
  exit 0
fi

test_roots=()
for candidate in TestSupport Tests UITests; do
  [[ -d "$candidate" ]] && test_roots+=("$candidate")
done

failures=0

fail_rule() {
  local id="$1" pattern="$2"; shift 2
  local output
  output="$(
    rg -n \
      --glob '*.swift' \
      --glob '!Generated/**' \
      --glob '!References/**' \
      "$pattern" "$@" 2>/dev/null || true
  )"
  if [[ -n "$output" ]]; then
    printf '\nERROR [%s]\n%s\n' "$id" "$output" >&2
    failures=$((failures + 1))
  fi
}

fail_logging_rule() {
  local id="$1" pattern="$2"; shift 2
  local output
  output="$(
    rg -n \
      --glob '*.swift' \
      --glob '!Generated/**' \
      --glob '!References/**' \
      --glob '!Sources/Core/Logging/OSDiagnosticsClient.swift' \
      "$pattern" "$@" 2>/dev/null || true
  )"
  if [[ -n "$output" ]]; then
    printf '\nERROR [%s]\n%s\n' "$id" "$output" >&2
    failures=$((failures + 1))
  fi
}

fail_rule \
  direct-console \
  '\b(print|debugPrint|dump|NSLog)[[:space:]]*\(' \
  "${all_roots[@]}"
fail_logging_rule \
  direct-oslog \
  '(^|[[:space:]])import[[:space:]]+OSLog([[:space:]]|$)|\b(Logger|OSSignposter)[[:space:]]*\(|\bos_log[[:space:]]*\(' \
  "${all_roots[@]}"
fail_rule \
  raw-localized-error \
  '\.localizedDescription\b' \
  "${all_roots[@]}"

fail_rule unchecked-sendable '@unchecked[[:space:]]+Sendable\b' "${all_roots[@]}"
fail_rule unsafe-nonisolated 'nonisolated[[:space:]]*\([[:space:]]*unsafe[[:space:]]*\)' "${all_roots[@]}"
fail_rule preconcurrency-import '@preconcurrency[[:space:]]+import\b' "${all_roots[@]}"
fail_rule detached-task '\bTask[[:space:]]*\.[[:space:]]*detached\b' "${all_roots[@]}"
fail_rule shared-singleton '\bstatic[[:space:]]+(let|var)[[:space:]]+shared\b' "${all_roots[@]}"
fail_rule direct-task-sleep '\bTask[[:space:]]*\.[[:space:]]*sleep[[:space:]]*\(' "${all_roots[@]}"
fail_rule timing-bypass 'DispatchQueue\b.*\.asyncAfter[[:space:]]*\(' "${all_roots[@]}"

if [[ ${#test_roots[@]} -gt 0 ]]; then
  fail_rule test-continuous-clock '\bContinuousClock[[:space:]]*\(' "${test_roots[@]}"
  fail_rule test-current-date '\bDate[[:space:]]*\([[:space:]]*\)' "${test_roots[@]}"
  fail_rule test-random-uuid '\bUUID[[:space:]]*\([[:space:]]*\)' "${test_roots[@]}"
  fail_rule test-random-api '\b(arc4random|drand48)[[:space:]]*\(|\.(random|randomElement)[[:space:]]*\(' "${test_roots[@]}"
fi

printf '\nSwift source-policy summary: %d error group(s).\n' "$failures"
[[ "$failures" -eq 0 ]]
