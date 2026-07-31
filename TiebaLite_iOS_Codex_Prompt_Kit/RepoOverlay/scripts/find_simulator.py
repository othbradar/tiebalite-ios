#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Device:
    runtime: str
    name: str
    udid: str
    state: str


def load_devices() -> list[Device]:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    devices: list[Device] = []
    for runtime, entries in payload.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for entry in entries:
            if not entry.get("isAvailable", True):
                continue
            devices.append(
                Device(
                    runtime=runtime,
                    name=entry["name"],
                    udid=entry["udid"],
                    state=entry.get("state", "Unknown"),
                )
            )
    return devices


def runtime_key(runtime: str) -> tuple[int, ...]:
    suffix = runtime.rsplit("iOS-", 1)[-1]
    parts: list[int] = []
    for token in suffix.split("-"):
        try:
            parts.append(int(token))
        except ValueError:
            parts.append(0)
    return tuple(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", choices=("iphone", "ipad"), required=True)
    parser.add_argument("--name-contains", default="")
    parser.add_argument("--format", choices=("udid", "destination", "json"), default="udid")
    args = parser.parse_args()

    prefix = "iPhone" if args.family == "iphone" else "iPad"
    candidates = [
        device
        for device in load_devices()
        if device.name.startswith(prefix)
        and args.name_contains.lower() in device.name.lower()
    ]
    if not candidates:
        print(f"No available {prefix} simulator found", file=sys.stderr)
        return 2

    candidates.sort(
        key=lambda item: (runtime_key(item.runtime), item.state == "Booted", item.name),
        reverse=True,
    )
    selected = candidates[0]

    if args.format == "udid":
        print(selected.udid)
    elif args.format == "destination":
        print(f"platform=iOS Simulator,id={selected.udid}")
    else:
        print(json.dumps(selected.__dict__, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
