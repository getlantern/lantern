#!/usr/bin/env python3
"""Check the native ABI contract in built Android AARs, APKs and AABs.

Reads ZIP entries and ELF headers directly, so CI does not need a host-specific
readelf binary. Pass --release for AOT APKs/AABs (libapp.so is absent in debug).
This verifies packaging, not startup safety or real-device compatibility.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import struct
import sys
import zipfile


# ELF e_ident[EI_CLASS], e_machine. Android's ARM ABIs are little-endian.
ELF_ABIS = {"armeabi-v7a": (1, 40), "arm64-v8a": (2, 183)}


class VerificationError(ValueError):
    pass


def parse_abis(value: str) -> set[str]:
    abis = value.split(",")
    if len(abis) != len(set(abis)) or any(abi not in ELF_ABIS for abi in abis):
        raise VerificationError(f"Expected a comma-separated, non-duplicate selection of {', '.join(ELF_ABIS)}")
    return set(abis)


def native_entry(name: str, kind: str) -> tuple[str, str] | None:
    if not name.endswith(".so"):
        return None
    parts = name.split("/")
    if len(parts) == 3 and parts[0] == {"aar": "jni", "apk": "lib"}.get(kind):
        return parts[1], parts[2]
    # Include every AAB module so features cannot bypass ABI and ELF checks.
    if kind == "aab" and len(parts) == 4 and parts[1] == "lib":
        return parts[2], f"{parts[0]}/{parts[3]}"
    return None


def verify_artifact(path: Path, kind: str, expected: set[str], release: bool = False) -> dict[str, set[str]]:
    libraries: dict[str, set[str]] = {}
    with zipfile.ZipFile(path) as archive:
        for entry in archive.infolist():
            native = native_entry(entry.filename, kind)
            if native is None:
                continue
            abi, name = native
            if abi not in expected:
                raise VerificationError(f"{path}: unexpected ABI {abi} ({entry.filename})")
            names = libraries.setdefault(abi, set())
            if name in names:
                raise VerificationError(f"{path}: duplicate native library {entry.filename}")
            names.add(name)
            with archive.open(entry) as stream:
                header = stream.read(64)
            if len(header) < 52 or header[:4] != b"\x7fELF" or header[5] != 1:
                raise VerificationError(f"{path}: {entry.filename} is not a little-endian ELF library")
            actual = (header[4], struct.unpack_from("<H", header, 18)[0])
            if actual != ELF_ABIS[abi]:
                raise VerificationError(f"{path}: {entry.filename} has ELF class/machine {actual}, expected {ELF_ABIS[abi]}")
            if struct.unpack_from("<H", header, 16)[0] != 3:
                raise VerificationError(f"{path}: {entry.filename} is not an ELF shared object")

    if set(libraries) != expected:
        raise VerificationError(f"{path}: missing ABIs {', '.join(sorted(expected - set(libraries)))}")
    required = {"libgojni.so"}
    if kind != "aar":
        required.add("libflutter.so")
        if release:
            required.add("libapp.so")
    if kind == "aab":
        required = {f"base/{name}" for name in required}
    required.update(*libraries.values())
    for abi, names in libraries.items():
        missing = required - names
        # Only Flutter's debug ARM64 engine bundles this optional validation
        # layer. All present ELF headers and every other library stay checked.
        if not release and kind == "apk" and abi == "armeabi-v7a":
            missing.discard("libVkLayer_khronos_validation.so")
        if missing:
            raise VerificationError(f"{path}: {abi} is missing native libraries: {', '.join(sorted(missing))}")
    return libraries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-abis", required=True, help="Comma-separated ABIs, e.g. armeabi-v7a,arm64-v8a")
    parser.add_argument("--app-abis", help="ABIs for APK/AAB artifacts when narrower than the AAR (per-ABI APKs)")
    parser.add_argument("--aar", action="append", type=Path, default=[])
    parser.add_argument("--apk", action="append", type=Path, default=[])
    parser.add_argument("--aab", action="append", type=Path, default=[])
    parser.add_argument("--release", action="store_true", help="Require Flutter AOT libapp.so in APK/AAB artifacts")
    args = parser.parse_args()
    if not (args.aar or args.apk or args.aab):
        parser.error("provide at least one --aar, --apk or --aab")
    try:
        expected = parse_abis(args.expected_abis)
        app_expected = parse_abis(args.app_abis) if args.app_abis else expected
        if not app_expected <= expected:
            raise VerificationError("--app-abis must be a subset of --expected-abis")
        aar_names = set()
        app_inventories = []
        for kind in ("aar", "apk", "aab"):
            for path in getattr(args, kind):
                inventory = verify_artifact(path, kind, expected if kind == "aar" else app_expected, args.release)
                if kind == "aar":
                    aar_names.update(*inventory.values())
                else:
                    app_inventories.append((path, inventory))
                counts = ", ".join(f"{abi} ({len(names)} libraries)" for abi, names in sorted(inventory.items()))
                print(f"Verified {path}: {counts}")
        # Every gomobile native library must survive packaging into the app.
        for path, inventory in app_inventories:
            for abi, names in inventory.items():
                packaged_names = {name.removeprefix("base/") for name in names}
                if aar_names - packaged_names:
                    raise VerificationError(f"{path}: {abi} omitted AAR libraries: {', '.join(sorted(aar_names - packaged_names))}")
    except (OSError, zipfile.BadZipFile, VerificationError) as error:
        print(f"Android ABI verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
