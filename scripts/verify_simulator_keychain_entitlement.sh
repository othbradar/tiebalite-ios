#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

if [[ -f scripts/project.env ]]; then
  # shellcheck disable=SC1091
  source scripts/project.env
fi

derived_data_path="${DERIVED_DATA_PATH:-.build/DerivedData}"
app="$derived_data_path/Build/Products/Debug-iphonesimulator/TiebaLite.app"
binary="$app/TiebaLite"
entitlements=
bundle_identifier=
application_identifier=

if [[ ! -d "$app" ]]; then
  echo "ERROR: Debug Simulator application is missing: $app" >&2
  exit 1
fi

if ! codesign --verify "$app" 2>/dev/null; then
  echo "ERROR: Debug Simulator application is not signed for local execution." >&2
  exit 1
fi

while IFS= read -r candidate; do
  entitlements="$candidate"
  break
done < <(
  find "$derived_data_path/Build/Intermediates.noindex" \
    -path '*/Debug-iphonesimulator/TiebaLite.build/DerivedSources/Entitlements-Simulated.plist' \
    -print
)

if [[ -z "$entitlements" ]]; then
  echo "ERROR: Debug Simulator application lacks generated entitlements." >&2
  exit 1
fi

if ! application_identifier="$(
  plutil -extract application-identifier raw -o - "$entitlements" 2>/dev/null
)"; then
  echo "ERROR: Debug Simulator application lacks application-identifier; Keychain reads would fail closed." >&2
  exit 1
fi

bundle_identifier="$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")"
if [[ "$application_identifier" != *".$bundle_identifier" ]]; then
  echo "ERROR: Simulator application-identifier does not match the built bundle identifier." >&2
  exit 1
fi

if ! otool -l "$binary" |
  rg -q 'sectname __entitlements'; then
  echo "ERROR: Debug Simulator binary does not embed simulated entitlements." >&2
  exit 1
fi

echo "OK: Debug Simulator application carries the Keychain application identifier entitlement."
