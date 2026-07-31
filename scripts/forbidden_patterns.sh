#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
cd "$repo"

roots=()
for candidate in App Sources; do
  [[ -d "$candidate" ]] && roots+=("$candidate")
done
if [[ ${#roots[@]} -eq 0 ]]; then
  echo "OK: no App/Sources directories yet; forbidden-pattern scan skipped."
  exit 0
fi

failures=0
warnings=0

fail_rule() {
  local id="$1" pattern="$2"; shift 2
  local output
  output="$(rg -n --glob '*.swift' --glob '!Generated/**' --glob '!References/**' "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$output" ]]; then
    printf '\nERROR [%s]\n%s\n' "$id" "$output" >&2
    failures=$((failures + 1))
  fi
}

warn_rule() {
  local id="$1" pattern="$2"; shift 2
  local output
  output="$(rg -n --glob '*.swift' --glob '!Generated/**' --glob '!References/**' "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$output" ]]; then
    printf '\nWARN [%s]\n%s\n' "$id" "$output" >&2
    warnings=$((warnings + 1))
  fi
}

fail_rule random-view-id '\.id\(\s*UUID\(\)\s*\)' "${roots[@]}"
fail_rule timing-patch 'DispatchQueue\.main\.asyncAfter' "${roots[@]}"
fail_rule global-screen-layout 'UIScreen\.main\.bounds' "${roots[@]}"
fail_rule force-try 'try!' "${roots[@]}"
fail_rule force-cast '\bas!' "${roots[@]}"
fail_rule production-fatal 'fatalError\(' "${roots[@]}"

if [[ -d Sources/Features ]]; then
  fail_rule feature-drag-gesture 'DragGesture\s*\(' Sources/Features
  fail_rule feature-direct-urlsession 'URLSession\.(shared|data|dataTask)' Sources/Features
  fail_rule feature-protobuf-import '^import SwiftProtobuf$' Sources/Features
  fail_rule feature-keychain-cookie 'HTTPCookieStorage\.shared|SecItem(Add|CopyMatching|Update|Delete)' Sources/Features
  fail_rule feature-random-motion '\.(easeIn|easeOut|easeInOut|linear)\(duration:|\.spring\(|\.snappy\(duration:' Sources/Features
  fail_rule feature-literal-animation '(\.animation|withAnimation)\s*\(\s*\.(linear|easeIn|easeOut|easeInOut|spring|interactiveSpring|snappy|bouncy|smooth)' Sources/Features
  fail_rule feature-page-tabview '\.tabViewStyle\s*\(\s*\.page|PageTabViewStyle\s*\(' Sources/Features
  fail_rule feature-uipagecontroller 'UIPageViewController' Sources/Features
  warn_rule feature-anyview 'AnyView\s*\(' Sources/Features
  warn_rule feature-ignores-safe-area '\.ignoresSafeArea\s*\(' Sources/Features
  warn_rule feature-large-zindex '\.zIndex\(\s*[1-9][0-9]+' Sources/Features
fi

warn_rule all-animation-calls '\.animation\s*\(|withAnimation\s*\(' "${roots[@]}"
warn_rule all-overlays '\.overlay\s*\(|fullScreenCover\s*\(|\.sheet\s*\(' "${roots[@]}"

policy_status=0
scripts/swift_source_policy.sh --root "$repo" || policy_status=$?

printf '\nForbidden-pattern summary: %d error group(s), %d warning group(s).\n' "$failures" "$warnings"
[[ "$failures" -eq 0 && "$policy_status" -eq 0 ]]
