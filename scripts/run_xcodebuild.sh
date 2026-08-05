#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

if [[ ! -f scripts/project.env ]]; then
  echo "ERROR: scripts/project.env is missing. Stage 03 must copy and fill scripts/project.env.example." >&2
  exit 66
fi
# shellcheck disable=SC1091
source scripts/project.env

: "${CONTAINER_KIND:?}"
: "${CONTAINER_PATH:?}"
: "${SCHEME:?}"
: "${TEST_PLAN:?}"
: "${UNIT_TEST_PLAN_CONFIGURATION:?}"
: "${UI_SMOKE_TEST_PLAN_CONFIGURATION:?}"
: "${FULL_TEST_PLAN_CONFIGURATION:?}"
: "${UNIT_TEST_TARGET:?}"
: "${UI_TEST_TARGET:?}"
: "${UI_SMOKE_TEST_IDENTIFIER:?}"
: "${UI_SHELL_SMOKE_TEST_IDENTIFIER:?}"
: "${FORUM_HOME_UI_TEST_IDENTIFIER:=TiebaLiteUITests/ForumHomeSmokeTests}"
: "${IPAD_UI_SMOKE_TEST_IDENTIFIER:?}"
: "${RENDERER_UI_TEST_IDENTIFIER:=TiebaLiteUITests/AppShellSmokeTests/testThreadContentRendererLabUsesDomainFixturesAndStableIntents}"
: "${IPAD_RENDERER_UI_TEST_IDENTIFIER:=TiebaLiteUITests/IPadAppShellSmokeTests/testThreadContentRendererLabSurvivesIPadProjectionAndRotation}"
: "${INTERACTION_UI_TEST_IDENTIFIER:?}"
: "${IPAD_INTERACTION_UI_TEST_IDENTIFIER:?}"
: "${DERIVED_DATA_PATH:=.build/DerivedData}"
: "${RESULTS_DIR:=Artifacts/TestResults}"

app_bundle_identifier="$(
  awk -F= '
    /^[[:space:]]*TIEBALITE_APP_BUNDLE_IDENTIFIER[[:space:]]*=/ {
      value = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' Config/Shared.xcconfig
)"
if [[ -z "$app_bundle_identifier" ]]; then
  echo "ERROR: TIEBALITE_APP_BUNDLE_IDENTIFIER is missing." >&2
  exit 66
fi
ui_test_runner_bundle_identifier="${app_bundle_identifier}.uitests.xctrunner"

if [[ ! -e "$CONTAINER_PATH" ]]; then
  echo "ERROR: generated container is missing: $CONTAINER_PATH" >&2
  exit 66
fi

case "$CONTAINER_KIND" in
  project) container_args=(-project "$CONTAINER_PATH") ;;
  workspace) container_args=(-workspace "$CONTAINER_PATH") ;;
  *) echo "ERROR: CONTAINER_KIND must be project or workspace" >&2; exit 64 ;;
esac

scripts/verify_swiftpm_lock.sh

mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "usage: $0 build|release-build|unit|ui-smoke|ui-smoke-ipad|ui-renderer|ui-renderer-ipad|ui-interaction|ui-interaction-ipad|tests|ipad-build" >&2
  exit 64
fi

mkdir -p "$DERIVED_DATA_PATH" "$RESULTS_DIR"
stamp="$(date +%Y%m%d-%H%M%S)-$$"

iphone_udid() {
  if [[ -n "${IPHONE_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "$IPHONE_SIMULATOR_UDID"
  else
    scripts/find_simulator.py --family iphone
  fi
}

ipad_udid() {
  if [[ -n "${IPAD_SIMULATOR_UDID:-}" ]]; then
    printf '%s\n' "$IPAD_SIMULATOR_UDID"
  else
    scripts/find_simulator.py --family ipad
  fi
}

run_build() {
  local label="$1"; shift
  local log="$RESULTS_DIR/${stamp}-${label}.log"
  local status
  echo "Running xcodebuild ($label). Log: $log"
  set +e
  if command -v xcbeautify >/dev/null 2>&1; then
    set -o pipefail
    xcodebuild "$@" 2>&1 | tee "$log" | xcbeautify
    status=${PIPESTATUS[0]}
  else
    xcodebuild "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
  fi
  set -e
  return "$status"
}

reset_project_ui_test_install() {
  local simulator_udid="$1"
  xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$simulator_udid" -b >/dev/null
  uninstall_project_bundle_if_present \
    "$simulator_udid" \
    "$ui_test_runner_bundle_identifier"
  uninstall_project_bundle_if_present \
    "$simulator_udid" \
    "$app_bundle_identifier"
}

project_bundle_is_installed() {
  local simulator_udid="$1"
  local bundle_identifier="$2"
  local installed_apps
  if ! installed_apps="$(xcrun simctl listapps "$simulator_udid")"; then
    echo "ERROR: unable to inspect installed Simulator applications." >&2
    return 2
  fi
  printf '%s\n' "$installed_apps" \
    | rg -F "CFBundleIdentifier = \"$bundle_identifier\";" >/dev/null
}

uninstall_project_bundle_if_present() {
  local simulator_udid="$1"
  local bundle_identifier="$2"
  local status=0

  project_bundle_is_installed \
    "$simulator_udid" \
    "$bundle_identifier" || status=$?
  case "$status" in
    0)
      xcrun simctl uninstall "$simulator_udid" "$bundle_identifier"
      ;;
    1)
      return
      ;;
    *)
      return "$status"
      ;;
  esac

  status=0
  project_bundle_is_installed \
    "$simulator_udid" \
    "$bundle_identifier" || status=$?
  if [[ "$status" -eq 0 ]]; then
    echo "ERROR: project bundle remains installed: $bundle_identifier" >&2
    return 1
  fi
  [[ "$status" -eq 1 ]]
}

common=(
  "${container_args[@]}"
  -scheme "$SCHEME"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -clonedSourcePackagesDirPath "$repo/.build/SourcePackages"
  -onlyUsePackageVersionsFromResolvedFile
  -skipPackageUpdates
)

case "$mode" in
  build)
    run_build build "${common[@]}" -destination 'generic/platform=iOS Simulator' build
    ;;
  release-build)
    run_build release-build "${common[@]}" -configuration Release \
      -destination 'generic/platform=iOS Simulator' build
    ;;
  ipad-build)
    run_build ipad-build "${common[@]}" -destination "platform=iOS Simulator,id=$(ipad_udid)" build
    ;;
  unit)
    result="$RESULTS_DIR/${stamp}-unit.xcresult"
    run_build unit "${common[@]}" -destination "platform=iOS Simulator,id=$(iphone_udid)" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UNIT_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$UNIT_TEST_TARGET"
    ;;
  ui-smoke)
    ui_iphone_udid="$(iphone_udid)"
    reset_project_ui_test_install "$ui_iphone_udid"
    result="$RESULTS_DIR/${stamp}-ui-smoke.xcresult"
    run_build ui-smoke "${common[@]}" \
      -destination "platform=iOS Simulator,id=$ui_iphone_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UI_SMOKE_TEST_PLAN_CONFIGURATION" \
      test \
      -only-testing:"$UI_SMOKE_TEST_IDENTIFIER" \
      -only-testing:"$UI_SHELL_SMOKE_TEST_IDENTIFIER" \
      -only-testing:"$FORUM_HOME_UI_TEST_IDENTIFIER"
    ;;
  ui-smoke-ipad)
    ui_ipad_udid="$(ipad_udid)"
    reset_project_ui_test_install "$ui_ipad_udid"
    result="$RESULTS_DIR/${stamp}-ui-smoke-ipad.xcresult"
    run_build ui-smoke-ipad "${common[@]}" \
      -destination "platform=iOS Simulator,id=$ui_ipad_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UI_SMOKE_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$IPAD_UI_SMOKE_TEST_IDENTIFIER"
    ;;
  ui-renderer)
    renderer_iphone_udid="$(iphone_udid)"
    reset_project_ui_test_install "$renderer_iphone_udid"
    result="$RESULTS_DIR/${stamp}-ui-renderer.xcresult"
    run_build ui-renderer "${common[@]}" \
      -destination "platform=iOS Simulator,id=$renderer_iphone_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UI_SMOKE_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$RENDERER_UI_TEST_IDENTIFIER"
    ;;
  ui-renderer-ipad)
    renderer_ipad_udid="$(ipad_udid)"
    reset_project_ui_test_install "$renderer_ipad_udid"
    result="$RESULTS_DIR/${stamp}-ui-renderer-ipad.xcresult"
    run_build ui-renderer-ipad "${common[@]}" \
      -destination "platform=iOS Simulator,id=$renderer_ipad_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UI_SMOKE_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$IPAD_RENDERER_UI_TEST_IDENTIFIER"
    ;;
  ui-interaction)
    interaction_iphone_udid="$(iphone_udid)"
    reset_project_ui_test_install "$interaction_iphone_udid"
    result="$RESULTS_DIR/${stamp}-ui-interaction.xcresult"
    run_build ui-interaction "${common[@]}" \
      -destination "platform=iOS Simulator,id=$interaction_iphone_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$FULL_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$INTERACTION_UI_TEST_IDENTIFIER"
    ;;
  ui-interaction-ipad)
    interaction_ipad_udid="$(ipad_udid)"
    reset_project_ui_test_install "$interaction_ipad_udid"
    result="$RESULTS_DIR/${stamp}-ui-interaction-ipad.xcresult"
    run_build ui-interaction-ipad "${common[@]}" \
      -destination "platform=iOS Simulator,id=$interaction_ipad_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$FULL_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$IPAD_INTERACTION_UI_TEST_IDENTIFIER"
    ;;
  tests)
    tests_iphone_udid="$(iphone_udid)"
    reset_project_ui_test_install "$tests_iphone_udid"
    result="$RESULTS_DIR/${stamp}-tests.xcresult"
    run_build tests "${common[@]}" \
      -destination "platform=iOS Simulator,id=$tests_iphone_udid" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$FULL_TEST_PLAN_CONFIGURATION" \
      test \
      -skip-testing:"$IPAD_UI_SMOKE_TEST_IDENTIFIER" \
      -skip-testing:"$IPAD_INTERACTION_UI_TEST_IDENTIFIER"
    ;;
  *)
    echo "ERROR: unknown mode: $mode" >&2
    exit 64
    ;;
esac

scripts/verify_swiftpm_lock.sh
