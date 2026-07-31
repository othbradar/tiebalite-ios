#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

repo="$(git rev-parse --show-toplevel)"
repo="$(cd "$repo" && pwd -P)"
# shellcheck disable=SC1091
source "$repo/scripts/path_safety.sh"
reference="$repo/References/TiebaLite-Android"
proto_root="$reference/app/src/main/protos"
manifest="$repo/Config/Protobuf/Personalized.inputs.tsv"
output_dir="$repo/Generated/Protobuf"
tracked_output="$output_dir"
expected_commit="5545326b2a8e0d784b2f3dfbcb219c7b121e61c2"
expected_protoc="35.1"
expected_generator="1.38.1"
root_proto="Personalized.proto"

if [[ "${1:-}" == "--output" ]]; then
  [[ $# -eq 2 ]] || { printf 'Usage: %s [--output directory]\n' "$0" >&2; exit 2; }
  if [[ "$2" = /* ]]; then
    output_dir="$2"
  else
    output_dir="$repo/$2"
  fi
  temporary_base="${TMPDIR:-/tmp}"
  tiebalite_require_safe_output_path \
    "$temporary_base" \
    "$output_dir" \
    'custom protobuf output'
  if [[ -e "$output_dir" ]]; then
    [[ -d "$output_dir" && ! -L "$output_dir" ]] || {
      printf 'ERROR: custom output must be a real directory.\n' >&2
      exit 1
    }
    [[ -z "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
      printf 'ERROR: custom output directory must be empty.\n' >&2
      exit 1
    }
  fi
elif [[ $# -ne 0 ]]; then
  printf 'Usage: %s [--output directory]\n' "$0" >&2
  exit 2
fi

case "$output_dir" in
  ""|/|"$repo"|"$repo/Generated")
    printf 'ERROR: unsafe protobuf output directory.\n' >&2
    exit 1
    ;;
esac
if [[ "$output_dir" != "$tracked_output" && -L "$output_dir" ]]; then
  printf 'ERROR: custom output cannot be a symlink.\n' >&2
  exit 1
fi
if [[ "$output_dir" == "$tracked_output" ]]; then
  tiebalite_require_safe_output_path \
    "$repo" \
    "$output_dir" \
    'tracked protobuf output'
fi

[[ -f "$manifest" ]] || { printf 'ERROR: missing input manifest.\n' >&2; exit 1; }
[[ -d "$proto_root" ]] || { printf 'ERROR: missing Android proto root.\n' >&2; exit 1; }
if [[ -e "$output_dir" && (! -d "$output_dir" || -L "$output_dir") ]]; then
  printf 'ERROR: protobuf output must be a real directory.\n' >&2
  exit 1
fi
tiebalite_require_symlink_free_tree "$output_dir" 'protobuf output tree'

actual_commit="$(git -C "$reference" rev-parse HEAD)"
[[ "$actual_commit" == "$expected_commit" ]] || {
  printf 'ERROR: Android reference is %s; expected %s.\n' \
    "$actual_commit" "$expected_commit" >&2
  exit 1
}
[[ -z "$(git -C "$reference" status --porcelain)" ]] || {
  printf 'ERROR: Android reference has local modifications.\n' >&2
  exit 1
}

actual_protoc="$(protoc --version | awk 'NR == 1 { print $2 }')"
actual_generator="$(protoc-gen-swift --version | awk 'NR == 1 { print $2 }')"
[[ "$actual_protoc" == "$expected_protoc" ]] || {
  printf 'ERROR: protoc is %s; expected %s.\n' \
    "$actual_protoc" "$expected_protoc" >&2
  exit 1
}
[[ "$actual_generator" == "$expected_generator" ]] || {
  printf 'ERROR: protoc-gen-swift is %s; expected %s.\n' \
    "$actual_generator" "$expected_generator" >&2
  exit 1
}

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/tiebalite-protos.XXXXXX")"
trap 'rm -rf "$temporary_root"' EXIT
manifest_paths="$temporary_root/manifest-paths.txt"
root_imports="$temporary_root/root-imports.txt"
generated="$temporary_root/generated"
mkdir -p "$generated"

sed -n \
  's/^[[:space:]]*import[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$proto_root/$root_proto" | sort > "$root_imports"

proto_args=()
proto_sources=()
while IFS=$'\t' read -r expected_hash relative_path relationship direct_imports; do
  [[ "$expected_hash" == \#* || -z "$expected_hash" ]] && continue
  [[ "$relative_path" == *.proto &&
     "$relative_path" != /* &&
     "$relative_path" != *..* ]] || {
    printf 'ERROR: unsafe manifest path.\n' >&2
    exit 1
  }

  source_path="$proto_root/$relative_path"
  [[ -f "$source_path" && ! -L "$source_path" ]] || {
    printf 'ERROR: missing or symlinked input: %s\n' "$relative_path" >&2
    exit 1
  }

  actual_hash="$(shasum -a 256 "$source_path" | awk '{ print $1 }')"
  [[ "$actual_hash" == "$expected_hash" ]] || {
    printf 'ERROR: hash mismatch for %s.\n' "$relative_path" >&2
    exit 1
  }

  actual_imports="$(
    sed -n \
      's/^[[:space:]]*import[[:space:]]*"\([^"]*\)".*/\1/p' \
      "$source_path" | sort | paste -sd, -
  )"
  [[ "${actual_imports:--}" == "$direct_imports" ]] || {
    printf 'ERROR: import lock mismatch for %s.\n' "$relative_path" >&2
    exit 1
  }

  expected_relationship=transitive
  if [[ "$relative_path" == "$root_proto" ]]; then
    expected_relationship=root
  elif rg -F -x -q "$relative_path" "$root_imports"; then
    expected_relationship=direct
  fi
  [[ "$relationship" == "$expected_relationship" ]] || {
    printf 'ERROR: dependency relationship mismatch for %s.\n' \
      "$relative_path" >&2
    exit 1
  }

  printf '%s\n' "$relative_path" >> "$manifest_paths"
  proto_args+=("$relative_path")
  proto_sources+=("$source_path")
done < "$manifest"

[[ "${#proto_args[@]}" -eq 51 ]] || {
  printf 'ERROR: expected 51 locked proto inputs; found %d.\n' \
    "${#proto_args[@]}" >&2
  exit 1
}
enum_matches="$(
  rg -n '^[[:space:]]*enum[[:space:]]+[A-Za-z_]' "${proto_sources[@]}" ||
    true
)"
[[ -z "$enum_matches" ]] || {
  printf 'ERROR: locked schema unexpectedly contains an enum.\n%s\n' \
    "$enum_matches" >&2
  exit 1
}

protoc \
  --proto_path="$proto_root" \
  --descriptor_set_out="$temporary_root/personalized.pb" \
  --include_imports \
  --dependency_out="$temporary_root/personalized.d" \
  "$root_proto"

sed '1s/^[^:]*:[[:space:]]*//' "$temporary_root/personalized.d" |
  tr -d '\\' |
  tr ' ' '\n' |
  sed '/^$/d' |
  sed "s#^$proto_root/##" |
  sort -u > "$temporary_root/resolved-paths.txt"
sort -u "$manifest_paths" > "$temporary_root/locked-paths.txt"
diff -u "$temporary_root/locked-paths.txt" "$temporary_root/resolved-paths.txt"

protoc \
  --proto_path="$proto_root" \
  --plugin="protoc-gen-swift=$(command -v protoc-gen-swift)" \
  --swift_out="$generated" \
  --swift_opt=Visibility=Public,FileNaming=FullPath,UseAccessLevelOnImports=false \
  "${proto_args[@]}"

generated_count="$(find "$generated" -type f -name '*.pb.swift' | wc -l | tr -d ' ')"
[[ "$generated_count" -eq 51 ]] || {
  printf 'ERROR: expected 51 generated Swift files; found %s.\n' \
    "$generated_count" >&2
  exit 1
}

(
  cd "$generated"
  find . -type f -name '*.pb.swift' | sed 's#^./##' | sort |
    while IFS= read -r file; do
      hash="$(shasum -a 256 "$file" | awk '{ print $1 }')"
      printf '%s  %s\n' "$hash" "$file"
    done
) > "$generated/GENERATED_SHA256SUMS"

cat > "$generated/GENERATION_METADATA.txt" <<EOF
endpoint=recommendations.personalized
reference_commit=$expected_commit
input_count=51
protoc=$expected_protoc
protoc_gen_swift=$expected_generator
swiftprotobuf_runtime=$expected_generator
schema_enum_count=0
swift_options=Visibility=Public,FileNaming=FullPath,UseAccessLevelOnImports=false
EOF

mkdir -p "$output_dir"
if [[ "$output_dir" == "$tracked_output" ]]; then
  output_root="$repo"
else
  output_root="$temporary_base"
fi
tiebalite_require_safe_output_path \
  "$output_root" \
  "$output_dir" \
  'protobuf output'
tiebalite_require_symlink_free_tree "$output_dir" 'protobuf output tree'
find "$output_dir" -type f \
  \( -name '*.pb.swift' -o -name 'GENERATED_SHA256SUMS' \
     -o -name 'GENERATION_METADATA.txt' \) -delete
cp -R "$generated/." "$output_dir/"

printf 'Generated %s Swift protobuf files for recommendations.personalized.\n' \
  "$generated_count"
