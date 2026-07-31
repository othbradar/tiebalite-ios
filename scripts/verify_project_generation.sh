#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
cd "$repo"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-xcodegen.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT

output_directory="$temporary_root/output"
first_project="$temporary_root/first.xcodeproj"
generated_project="$output_directory/TiebaLite.xcodeproj"
mkdir -p "$output_directory"

generate() {
  xcodegen generate \
    --spec "$repo/project.yml" \
    --project "$output_directory" \
    --project-root "$repo" \
    --no-env \
    --quiet
}

generate
mv "$generated_project" "$first_project"
generate

diff -ru "$first_project" "$generated_project"
printf 'OK: two clean XcodeGen runs produced identical projects.\n'
