#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

if [[ -f scripts/project.env ]]; then
  # shellcheck disable=SC1091
  source scripts/project.env
fi
derived_data_path="${DERIVED_DATA_PATH:-.build/DerivedData}"
release_intermediates="$derived_data_path/Build/Intermediates.noindex/TiebaLite.build/Release-iphonesimulator/TiebaLite.build"
release_app="$derived_data_path/Build/Products/Release-iphonesimulator/TiebaLite.app"
release_binary="$release_app/TiebaLite"
forbidden_pattern='/(TestSupport|Tests|UITests)/|/App/Debug|/Sources/InteractionKit/InteractionLab/|LaunchScenario|Harness|FixtureLoader'
symbol_pattern='TIEBALITE_(TEST_SUPPORT|DEBUG_GALLERY|INTERACTION_LAB|THREAD_CONTENT_RENDERER_LAB)_CANARY|app\.empty-shell|network\.offline|renderer\.thread-content|LaunchScenario|Debug(ComponentGallery|InteractionLab|SwiftUITabPager|ZoomImage|ThreadContentRenderer)|Harness(Mock|Controlled|Fixture|Recording|Sequence|InMemory|Latest|Continuation|Renderer)'
failures=0
file_list_count=0

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  failures=$((failures + 1))
}

if [[ ! -d "$release_intermediates" ]]; then
  fail "Release intermediates are missing."
else
  while IFS= read -r file_list; do
    file_list_count=$((file_list_count + 1))
    if ! rg -F '/App/AppEnvironment.swift' "$file_list" >/dev/null; then
      fail "Release source proof is missing AppEnvironment.swift: $file_list"
    fi
    if ! rg -F '/Sources/Core/Networking/HTTPClient.swift' "$file_list" >/dev/null; then
      fail "Release source proof is missing HTTPClient.swift: $file_list"
    fi
    if ! rg -F '/Sources/DesignSystem/Motion.swift' "$file_list" >/dev/null; then
      fail "Release source proof is missing Motion.swift: $file_list"
    fi
    if ! rg -F '/Sources/Features/ThreadReader/Presentation/ThreadContentRenderer.swift' \
      "$file_list" >/dev/null; then
      fail "Release source proof is missing ThreadContentRenderer.swift: $file_list"
    fi
    if ! rg -F '/Sources/InteractionKit/Pager/PagerContainer.swift' \
      "$file_list" >/dev/null; then
      fail "Release source proof is missing PagerContainer.swift: $file_list"
    fi
    if ! rg -F '/Sources/Features/MediaViewer/Presentation/MediaViewer.swift' \
      "$file_list" >/dev/null; then
      fail "Release source proof is missing MediaViewer.swift: $file_list"
    fi
    if rg -n "$forbidden_pattern" "$file_list" >/dev/null; then
      fail "Release source list contains test-only input: $file_list"
    fi
  done < <(
    find "$release_intermediates" -type f -name 'TiebaLite.SwiftFileList' -print
  )
fi
if [[ "$file_list_count" -eq 0 ]]; then
  fail "No Release TiebaLite Swift file list was found."
fi

if [[ ! -x "$release_binary" ]]; then
  fail "Release application binary is missing."
else
  strings_output="$(mktemp "${TMPDIR:-/tmp}/tiebalite-release-strings.XXXXXX")"
  symbols_output="$(mktemp "${TMPDIR:-/tmp}/tiebalite-release-symbols.XXXXXX")"
  trap 'rm -f "$strings_output" "$symbols_output"' EXIT

  strings -a "$release_binary" > "$strings_output"
  if rg -n "$symbol_pattern" "$strings_output" >/dev/null; then
    fail "Release binary contains a test-support string or symbol canary."
  fi
  if ! rg -F 'AppCompositionRoot' "$strings_output" >/dev/null; then
    fail "Release binary lacks the Stage 04 production-composition positive control."
  fi
  if ! rg -F 'AppNavigationStore' "$strings_output" >/dev/null; then
    fail "Release binary lacks the Stage 05 navigation positive control."
  fi
  if ! rg -F 'MediaViewer' "$strings_output" >/dev/null; then
    fail "Release binary lacks the Stage 09 MediaViewer positive control."
  fi

  if nm "$release_binary" > "$symbols_output" 2>/dev/null; then
    xcrun swift-demangle < "$symbols_output" > "${symbols_output}.demangled"
    if rg -n "$symbol_pattern" "${symbols_output}.demangled" >/dev/null; then
      fail "Release symbol table contains a test-support symbol."
    fi
    rm -f "${symbols_output}.demangled"
  fi
fi

if [[ -d "$release_app" ]]; then
  if find "$release_app" \
    \( -name Fixtures -o -name manifest.json -o -name '*.pb' -o -name '*.svg' \) \
    -print -quit | rg . >/dev/null; then
    fail "Release application bundle contains a fixture resource."
  fi
  if [[ -d "$release_app/PlugIns" ]]; then
    fail "Release application bundle unexpectedly contains test plug-ins."
  fi
else
  fail "Release application bundle is missing."
fi

if [[ "$failures" -ne 0 ]]; then
  echo "Release test-support isolation failed: $failures check(s)." >&2
  exit 1
fi
echo "OK: Release includes renderer, Pager and MediaViewer while excluding test support and Debug labs."
