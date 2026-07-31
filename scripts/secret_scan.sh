#!/usr/bin/env bash
set -euo pipefail
repo="$(git rev-parse --show-toplevel)"
cd "$repo"

failures=0
scan_roots=()
for candidate in \
  App \
  Sources \
  Resources \
  TestSupport \
  Tests \
  UITests \
  Config \
  Specs \
  Docs \
  project.yml \
  scripts/project.env.example; do
  [[ -e "$candidate" ]] && scan_roots+=("$candidate")
done
[[ ${#scan_roots[@]} -gt 0 ]] || { echo "OK: no scan roots yet."; exit 0; }

# These are intentionally high-confidence patterns. This check complements, but does not
# replace, a dedicated secret scanner or manual review of binary/screenshot attachments.
patterns=(
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'Cookie:[[:space:]]*[^<[:space:]][^[:space:]]+'
  "(BDUSS|STOKEN)[[:space:]]*[:=][[:space:]]*\\\\?[\"']?[A-Za-z0-9._-]{20,}"
  "(password|passwd)[[:space:]]*[:=][[:space:]]*\\\\?[\"'][^\"']{6,}"
  'sk-[A-Za-z0-9_-]{24,}'
  'AKIA[0-9A-Z]{16}'
)

for pattern in "${patterns[@]}"; do
  output="$(rg -n -i --glob '!References/**' --glob '!Generated/**' "$pattern" "${scan_roots[@]}" 2>/dev/null || true)"
  if [[ -n "$output" ]]; then
    printf 'ERROR: possible secret pattern:\n%s\n' "$output" >&2
    failures=$((failures + 1))
  fi
done

[[ "$failures" -eq 0 ]] && echo "OK: lightweight secret scan found no high-confidence match."
[[ "$failures" -eq 0 ]]
