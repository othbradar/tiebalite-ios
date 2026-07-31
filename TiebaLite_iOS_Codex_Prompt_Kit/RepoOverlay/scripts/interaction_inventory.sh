#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"
output="${1:-}"
roots=()
for candidate in App Sources; do
  [[ -d "$candidate" ]] && roots+=("$candidate")
done

emit() {
  local title="$1" pattern="$2"
  printf '\n## %s\n\n' "$title"
  if [[ ${#roots[@]} -eq 0 ]]; then
    echo '(no App/Sources directories)'
  else
    rg -n --glob '*.swift' --glob '!Generated/**' --glob '!References/**' \
      "$pattern" "${roots[@]}" 2>/dev/null || echo '(none)'
  fi
}

run_inventory() {
  echo '# Interaction inventory'
  echo
  echo "Repository: $repo"
  echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo UNKNOWN)"
  emit 'Animations and transitions' '\.animation\s*\(|withAnimation\s*\(|\.transition\s*\(|matchedGeometryEffect|UIView(PropertyAnimator|\.animate)|CATransaction'
  emit 'Gestures' 'DragGesture\s*\(|MagnificationGesture\s*\(|MagnifyGesture\s*\(|TapGesture\s*\(|LongPressGesture\s*\(|\.gesture\s*\(|simultaneousGesture|highPriorityGesture|UIGestureRecognizer'
  emit 'Presentation and overlays' '\.overlay\s*\(|\.background\s*\(|\.sheet\s*\(|fullScreenCover\s*\(|popover\s*\(|safeAreaInset\s*\(|ignoresSafeArea\s*\(|\.zIndex\s*\('
  emit 'Scrolling and paging' 'ScrollView\s*\(|List\s*\{|scrollPosition\s*\(|scrollTargetBehavior|TabView\s*\(|UIPageViewController|UICollectionView|UIScrollView'
  emit 'Navigation' 'NavigationStack|NavigationSplitView|NavigationPath|navigationDestination|dismiss\s*\(|presentationMode'
  emit 'Identity and lifecycle' '\.id\s*\(|ForEach\s*\(|\.task\s*\(|onAppear\s*\{|onDisappear\s*\{|updateUIView|updateUIViewController|dismantleUIView|dismantleUIViewController'
}

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  run_inventory > "$output"
  echo "Wrote $output"
else
  run_inventory
fi
