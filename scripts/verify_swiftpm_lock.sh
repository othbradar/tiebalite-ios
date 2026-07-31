#!/usr/bin/env bash
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
canonical="$repo/Config/SwiftPM/Package.resolved"
generated="$repo/TiebaLite.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
expected_revision="55d7a1cc5666b85c13464aea1c4b4a90feccb4c8"

[[ -f "$canonical" ]] || {
  printf 'ERROR: canonical SwiftPM lock is missing.\n' >&2
  exit 66
}

python3 - "$canonical" "$expected_revision" <<'PY'
import json
import sys

path, expected_revision = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    document = json.load(handle)

pins = document.get("pins")
if not isinstance(pins, list) or len(pins) != 1:
    raise SystemExit("ERROR: Package.resolved must contain exactly one pin.")
if document.get("version") != 3 or not document.get("originHash"):
    raise SystemExit("ERROR: Package.resolved metadata is incomplete.")

pin = pins[0]
state = pin.get("state", {})
expected = {
    "identity": "swift-protobuf",
    "location": "https://github.com/apple/swift-protobuf.git",
    "version": "1.38.1",
    "revision": expected_revision,
}
actual = {
    "identity": pin.get("identity"),
    "location": pin.get("location"),
    "version": state.get("version"),
    "revision": state.get("revision"),
}
if actual != expected or state.get("branch") is not None:
    raise SystemExit(f"ERROR: unexpected SwiftPM pin: {actual!r}")
if pin.get("kind") != "remoteSourceControl":
    raise SystemExit("ERROR: SwiftProtobuf pin must be remote source control.")
if set(state) != {"revision", "version"}:
    raise SystemExit("ERROR: SwiftProtobuf state contains an unapproved selector.")
PY

[[ -f "$generated" && ! -L "$generated" ]] || {
  printf 'ERROR: generated SwiftPM lock is missing or symlinked.\n' >&2
  exit 66
}
cmp "$canonical" "$generated"

known_locks="$(
  git -C "$repo" ls-files --cached --others --exclude-standard \
    -- '*Package.resolved' | sort
)"
[[ "$known_locks" == "Config/SwiftPM/Package.resolved" ]] || {
  printf 'ERROR: only Config/SwiftPM/Package.resolved may be tracked.\n%s\n' \
    "$known_locks" >&2
  exit 1
}

printf 'OK: SwiftProtobuf is exactly locked to 1.38.1 (%s).\n' \
  "$expected_revision"
