#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PHASE="${1:-UNNAMED}"
ENV_FILE="${PROJECT_ENV_FILE:-scripts/project.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

UDID="${IPHONE_SIMULATOR_UDID:-}"
if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available -j | \
    python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; xs=[x for v in d.values() for x in v if x.get("isAvailable") and "iPhone" in x.get("name","")]; print(next((x["udid"] for x in xs if x.get("state")=="Booted"), xs[0]["udid"] if xs else ""))')"
fi
if [[ -z "$UDID" ]]; then
  echo "No available iPhone Simulator found." >&2
  exit 2
fi

DERIVED="$ROOT/Artifacts/VisualReview/${PHASE}/DerivedData"
mkdir -p "$DERIVED"

make generate

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator

xcodebuild build \
  -project TiebaLite.xcodeproj \
  -scheme TiebaLite \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=${UDID}" \
  -derivedDataPath "$DERIVED"

APP="$DERIVED/Build/Products/Debug-iphonesimulator/TiebaLite.app"
if [[ ! -d "$APP" ]]; then
  echo "Built app not found: $APP" >&2
  exit 3
fi
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")"

if ! codesign --verify "$APP" 2>/dev/null; then
  echo "Built app is not signed for local Simulator execution: $APP" >&2
  exit 4
fi

ENTITLEMENTS="$(find "$DERIVED/Build/Intermediates.noindex" \
  -path '*/Debug-iphonesimulator/TiebaLite.build/DerivedSources/Entitlements-Simulated.plist' \
  -print -quit)"
if [[ -z "$ENTITLEMENTS" ]]; then
  echo "Built app lacks generated Simulator entitlements." >&2
  exit 5
fi
APPLICATION_IDENTIFIER="$(
  plutil -extract application-identifier raw -o - "$ENTITLEMENTS" 2>/dev/null || true
)"
if [[ "$APPLICATION_IDENTIFIER" != *".${BUNDLE_ID}" ]]; then
  echo "Simulator application-identifier does not match the bundle identifier." >&2
  exit 6
fi
if ! otool -l "$APP/TiebaLite" | rg -q 'sectname __entitlements'; then
  echo "Built app binary does not embed Simulator entitlements." >&2
  exit 7
fi

# Preserve the app container and Keychain: terminate, overwrite install, launch.
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

cat <<EOF
VISUAL_REVIEW_APP_READY
phase=$PHASE
udid=$UDID
bundle_id=$BUNDLE_ID
app=$APP
Do not uninstall or erase this Simulator.
Navigate to the target screen, then run:
  scripts/visual_review_capture.sh "$PHASE" <screen-name> "$UDID"
EOF
