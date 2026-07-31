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
: "${DERIVED_DATA_PATH:=.build/DerivedData}"
: "${RESULTS_DIR:=Artifacts/TestResults}"

if [[ ! -e "$CONTAINER_PATH" ]]; then
  echo "ERROR: generated container is missing: $CONTAINER_PATH" >&2
  exit 66
fi

case "$CONTAINER_KIND" in
  project) container_args=(-project "$CONTAINER_PATH") ;;
  workspace) container_args=(-workspace "$CONTAINER_PATH") ;;
  *) echo "ERROR: CONTAINER_KIND must be project or workspace" >&2; exit 64 ;;
esac

mode="${1:-}"
if [[ -z "$mode" ]]; then
  echo "usage: $0 build|release-build|unit|ui-smoke|tests|ipad-build" >&2
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

common=("${container_args[@]}" -scheme "$SCHEME" -derivedDataPath "$DERIVED_DATA_PATH")

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
    result="$RESULTS_DIR/${stamp}-ui-smoke.xcresult"
    run_build ui-smoke "${common[@]}" -destination "platform=iOS Simulator,id=$(iphone_udid)" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$UI_SMOKE_TEST_PLAN_CONFIGURATION" \
      test -only-testing:"$UI_SMOKE_TEST_IDENTIFIER"
    ;;
  tests)
    result="$RESULTS_DIR/${stamp}-tests.xcresult"
    run_build tests "${common[@]}" -destination "platform=iOS Simulator,id=$(iphone_udid)" \
      -resultBundlePath "$result" -testPlan "$TEST_PLAN" \
      -only-test-configuration "$FULL_TEST_PLAN_CONFIGURATION" test
    ;;
  *)
    echo "ERROR: unknown mode: $mode" >&2
    exit 64
    ;;
esac
