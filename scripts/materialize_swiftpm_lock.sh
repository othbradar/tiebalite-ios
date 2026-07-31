#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
canonical="$repo/Config/SwiftPM/Package.resolved"
container="${1:-$repo/TiebaLite.xcodeproj}"

if [[ "$container" != /* ]]; then
  container="$repo/$container"
fi
case "$container" in
  *.xcodeproj)
    destination="$container/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    ;;
  *.xcworkspace)
    destination="$container/xcshareddata/swiftpm/Package.resolved"
    ;;
  *)
    printf 'ERROR: expected an .xcodeproj or .xcworkspace container.\n' >&2
    exit 64
    ;;
esac

[[ -f "$canonical" && ! -L "$canonical" ]] || {
  printf 'ERROR: canonical SwiftPM lock is missing: %s\n' "$canonical" >&2
  exit 66
}
[[ -d "$container" && ! -L "$container" ]] || {
  printf 'ERROR: generated Xcode container is missing or symlinked.\n' >&2
  exit 66
}

resolved_container="$(
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$container"
)"
resolved_repo="$(
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$repo"
)"
resolved_temporary_root="$(
  python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' \
    "${TMPDIR:-/tmp}"
)"
case "$resolved_container" in
  "$resolved_repo"/*|"$resolved_temporary_root"/*) ;;
  *)
    printf 'ERROR: generated Xcode container is outside approved roots.\n' >&2
    exit 1
    ;;
esac

for candidate in \
  "$container/project.xcworkspace" \
  "$(dirname "$(dirname "$destination")")" \
  "$(dirname "$destination")" \
  "$destination"
do
  [[ ! -L "$candidate" ]] || {
    printf 'ERROR: SwiftPM lock destination crosses a symlink.\n' >&2
    exit 1
  }
done

mkdir -p "$(dirname "$destination")"
cp "$canonical" "$destination"
cmp "$canonical" "$destination"
printf 'Materialized canonical SwiftPM lock into %s.\n' "$container"
