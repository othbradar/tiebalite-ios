#!/usr/bin/env bash
set -euo pipefail

kit_dir="$(cd "$(dirname "$0")" && pwd)"
destination="${1:-}"
if [[ -z "$destination" ]]; then
  echo "usage: $0 /absolute/path/to/TiebaLiteIOS" >&2
  exit 64
fi
copy_tree() {
  local source="$1" target="$2"
  mkdir -p "$target"
  if command -v ditto >/dev/null 2>&1; then
    ditto "$source" "$target"
  else
    cp -a "$source"/. "$target"/
  fi
}

mkdir -p "$destination"
if [[ -n "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "ERROR: destination is not empty: $destination" >&2
  echo "Use ditto manually if you intentionally want to overlay an existing repository." >&2
  exit 65
fi
copy_tree "$kit_dir/RepoOverlay" "$destination"
copy_tree "$kit_dir/Prompts" "$destination/Prompts"
cp "$kit_dir/FIRST_CODEX_MESSAGE.txt" "$destination/Prompts/FIRST_CODEX_MESSAGE.txt"
cd "$destination"
git init -b main 2>/dev/null || { git init; git branch -M main; }
printf '\nInstalled repository guardrails in %s\n' "$destination"
printf 'Next:\n'
printf '  git submodule add -b 4.0-dev https://github.com/zzc10086/TiebaLite.git References/TiebaLite-Android\n'
printf '  git add -A && git commit -m "chore: install Codex project guardrails"\n'
printf '  Open this folder in Codex and paste Prompts/FIRST_CODEX_MESSAGE.txt.\n'
