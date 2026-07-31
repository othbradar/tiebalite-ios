#!/usr/bin/env bash

tiebalite_require_safe_output_path() {
  local allowed_root="$1"
  local target="$2"
  local label="$3"

  python3 - "$allowed_root" "$target" "$label" <<'PY'
import os
import sys

root_input, target_input, label = sys.argv[1:]
if ".." in target_input.split(os.sep):
    raise SystemExit(f"ERROR: {label} contains an unsafe path component.")

root = os.path.abspath(root_input)
resolved_root = os.path.realpath(root)
target = os.path.abspath(target_input)

if not os.path.isdir(root):
    raise SystemExit(f"ERROR: {label} root is not a directory: {root}")
if target in (root, resolved_root):
    raise SystemExit(f"ERROR: {label} is outside its allowed root: {target}")

resolved_target = os.path.realpath(target)
if os.path.commonpath((resolved_root, resolved_target)) != resolved_root:
    raise SystemExit(
        f"ERROR: {label} resolves outside its allowed root: {resolved_target}"
    )

if os.path.commonpath((root, target)) == root:
    walk_root = root
    walk_target = target
elif os.path.commonpath((resolved_root, target)) == resolved_root:
    walk_root = resolved_root
    walk_target = target
elif os.path.commonpath((resolved_root, resolved_target)) == resolved_root:
    walk_root = resolved_root
    walk_target = resolved_target
else:
    raise SystemExit(f"ERROR: {label} is outside its allowed root: {target}")

current = walk_root
for component in os.path.relpath(walk_target, walk_root).split(os.sep):
    if component in ("", ".", ".."):
        raise SystemExit(f"ERROR: {label} contains an unsafe path component.")
    current = os.path.join(current, component)
    if os.path.islink(current):
        raise SystemExit(f"ERROR: {label} path component is symlinked: {current}")
PY
}

tiebalite_require_symlink_free_tree() {
  local tree="$1"
  local label="$2"
  local first_link

  if [[ -L "$tree" ]]; then
    printf 'ERROR: %s is symlinked: %s\n' "$label" "$tree" >&2
    return 1
  fi
  if [[ ! -e "$tree" ]]; then
    return 0
  fi
  [[ -d "$tree" ]] || {
    printf 'ERROR: %s is not a directory: %s\n' "$label" "$tree" >&2
    return 1
  }

  first_link="$(find "$tree" -type l -print -quit)"
  if [[ -n "$first_link" ]]; then
    printf 'ERROR: %s contains a symlink: %s\n' "$label" "$first_link" >&2
    return 1
  fi
}
