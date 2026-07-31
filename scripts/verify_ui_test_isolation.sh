#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

if [[ -f scripts/project.env ]]; then
  # shellcheck disable=SC1091
  source scripts/project.env
fi
derived_data_path="${DERIVED_DATA_PATH:-.build/DerivedData}"
intermediates="$derived_data_path/Build/Intermediates.noindex/TiebaLite.build/UITesting-iphonesimulator"
uitesting_app="$derived_data_path/Build/Products/UITesting-iphonesimulator/TiebaLite.app"
app_debug_binary="$uitesting_app/TiebaLite.debug.dylib"
failures=0

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  failures=$((failures + 1))
}

app_list_count=0
while IFS= read -r file_list; do
  app_list_count=$((app_list_count + 1))
  if ! rg -F '/TestSupport/LaunchScenarios/LaunchScenario.swift' "$file_list" >/dev/null; then
    fail "UITesting App source list lacks the launch-scenario positive control."
  fi
  if ! rg -F '/TestSupport/LaunchScenarios/HarnessContinuationGate.swift' "$file_list" >/dev/null; then
    fail "UITesting App source list lacks the harness positive control."
  fi
  if rg -F '/TestSupport/FixtureLoader.swift' "$file_list" >/dev/null; then
    fail "UITesting App source list contains the unit-only fixture loader."
  fi
  if ! rg -F '/App/DebugComponentGalleryView.swift' "$file_list" >/dev/null; then
    fail "UITesting App source list lacks the Debug gallery positive control."
  fi
done < <(
  find "$intermediates/TiebaLite.build" -type f -name 'TiebaLite.SwiftFileList' -print 2>/dev/null
)
if [[ "$app_list_count" -eq 0 ]]; then
  fail "No UITesting App Swift file list was found."
fi

unit_list_count=0
while IFS= read -r file_list; do
  unit_list_count=$((unit_list_count + 1))
  if ! rg -F '/TestSupport/FixtureLoader.swift' "$file_list" >/dev/null; then
    fail "Unit test source list lacks FixtureLoader.swift."
  fi
  if ! rg -F '/TestSupport/LaunchScenarios/HarnessMockHTTPClient.swift' "$file_list" >/dev/null; then
    fail "Unit test source list lacks the controlled HTTP harness."
  fi
done < <(
  find "$intermediates/TiebaLiteTests.build" \
    -type f -name 'TiebaLiteTests.SwiftFileList' -print 2>/dev/null
)
if [[ "$unit_list_count" -eq 0 ]]; then
  fail "No unit test Swift file list was found."
fi

ui_list_count=0
while IFS= read -r file_list; do
  ui_list_count=$((ui_list_count + 1))
  if rg -n '/TestSupport/' "$file_list" >/dev/null; then
    fail "UI test target directly compiles TestSupport."
  fi
  if ! rg -F '/UITests/UITestHarness.swift' "$file_list" >/dev/null; then
    fail "UI test source list lacks its typed harness."
  fi
  if ! rg -F '/UITests/AppShellSmokeTests.swift' "$file_list" >/dev/null; then
    fail "UI test source list lacks AppShellSmokeTests.swift."
  fi
  if ! rg -F '/UITests/IPadAppShellSmokeTests.swift' "$file_list" >/dev/null; then
    fail "UI test source list lacks IPadAppShellSmokeTests.swift."
  fi
done < <(
  find "$intermediates/TiebaLiteUITests.build" \
    -type f -name 'TiebaLiteUITests.SwiftFileList' -print 2>/dev/null
)
if [[ "$ui_list_count" -eq 0 ]]; then
  fail "No UI test Swift file list was found."
fi

if [[ ! -f "$app_debug_binary" ]]; then
  fail "UITesting App debug binary is missing."
elif ! strings -a "$app_debug_binary" \
  | rg -F 'TIEBALITE_TEST_SUPPORT_CANARY' >/dev/null; then
  fail "UITesting binary lacks the exact isolation positive control."
fi
if [[ -f "$app_debug_binary" ]] && ! strings -a "$app_debug_binary" \
  | rg -F 'TIEBALITE_DEBUG_GALLERY_CANARY' >/dev/null; then
  fail "UITesting binary lacks the Debug gallery positive control."
fi

if [[ "$failures" -ne 0 ]]; then
  echo "UI test-support isolation failed: $failures check(s)." >&2
  exit 1
fi
echo "OK: UITesting App, unit target, UI target and Debug gallery boundaries are explicit."
