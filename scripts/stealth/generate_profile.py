#!/usr/bin/env python3
"""Generate and validate Stealth Lantern build profiles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import secrets
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
VALID_MODES = ("stealth-vpn", "stealth-novpn")
DEFAULTS = {
    "appName": "Lantern",
    "sessionName": "LanternVpn",
    "nativeLibraryName": "liblantern",
    "denylistVersion": 0,
}
DART_DEFINE_KEYS = {
    "mode": "STEALTH_MODE",
    "packageName": "STEALTH_PACKAGE_NAME",
    "appName": "STEALTH_APP_NAME",
    "sessionName": "STEALTH_SESSION_NAME",
    "nativeLibraryName": "STEALTH_NATIVE_LIBRARY_NAME",
    "goObfuscationSeed": "STEALTH_GO_OBFUSCATION_SEED",
    "denylistVersion": "STEALTH_DENYLIST_VERSION",
}
PACKAGE_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$")
NATIVE_LIB_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


class ProfileError(ValueError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except OSError as exc:
        raise ProfileError(f"failed to read profile input {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ProfileError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ProfileError(f"profile input {path} must be a JSON object")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def new_profile_id() -> str:
    return f"stl_{secrets.token_hex(6)}"


def default_package_name(profile_id: str) -> str:
    suffix = profile_id.removeprefix("stl_")
    return f"org.getlantern.lantern.stealth.s{suffix}"


def coerce_denylist_version(value: Any) -> int:
    try:
        version = int(value)
    except (TypeError, ValueError) as exc:
        raise ProfileError("denylistVersion must be a non-negative integer") from exc
    if version < 0:
        raise ProfileError("denylistVersion must be a non-negative integer")
    return version


def normalize_native_library_name(value: Any) -> str:
    name = str(value).strip()
    if name.startswith("lib"):
        name = name[3:]
    for suffix in (".so", ".dylib", ".dll", ".aar"):
        if name.endswith(suffix):
            name = name[: -len(suffix)]
            break
    if not name or not NATIVE_LIB_RE.fullmatch(name):
        raise ProfileError(
            "nativeLibraryName must contain only letters, numbers, and underscores"
        )
    return f"lib{name}"


def validate_profile(profile: dict[str, Any]) -> dict[str, Any]:
    mode = str(profile.get("mode", "")).strip()
    if mode not in VALID_MODES:
        raise ProfileError(f"mode must be one of: {', '.join(VALID_MODES)}")

    package_name = str(profile.get("packageName", "")).strip()
    if not PACKAGE_RE.fullmatch(package_name):
        raise ProfileError(
            "packageName must be a valid Android application ID with at least two segments"
        )

    app_name = str(profile.get("appName", "")).strip()
    if not app_name:
        raise ProfileError("appName is required")

    session_name = str(profile.get("sessionName", "")).strip()
    if not session_name:
        raise ProfileError("sessionName is required")

    go_obfuscation_seed = str(
        profile.get("goObfuscationSeed") or profile.get("obfuscationSeed", "")
    ).strip()
    if not go_obfuscation_seed:
        raise ProfileError("goObfuscationSeed is required")

    normalized = dict(profile)
    normalized["mode"] = mode
    normalized["packageName"] = package_name
    normalized["appName"] = app_name
    normalized["sessionName"] = session_name
    normalized["nativeLibraryName"] = normalize_native_library_name(
        profile.get("nativeLibraryName", DEFAULTS["nativeLibraryName"])
    )
    normalized.pop("obfuscationSeed", None)
    normalized["goObfuscationSeed"] = go_obfuscation_seed
    normalized["denylistVersion"] = coerce_denylist_version(
        profile.get("denylistVersion", DEFAULTS["denylistVersion"])
    )
    normalized["schemaVersion"] = SCHEMA_VERSION
    return normalized


def build_profile(args: argparse.Namespace) -> dict[str, Any]:
    loaded = {}
    if args.input:
        loaded = load_json(args.input)
    elif args.output and args.output.exists():
        loaded = load_json(args.output)

    profile_id = str(loaded.get("profileId") or new_profile_id())
    generated_at = str(
        loaded.get("generatedAt")
        or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    )

    profile = {
        "schemaVersion": SCHEMA_VERSION,
        "profileId": profile_id,
        "generatedAt": generated_at,
        "mode": args.mode or loaded.get("mode"),
        "packageName": args.package_name
        or loaded.get("packageName")
        or default_package_name(profile_id),
        "appName": args.app_name or loaded.get("appName") or DEFAULTS["appName"],
        "sessionName": args.session_name
        or loaded.get("sessionName")
        or DEFAULTS["sessionName"],
        "nativeLibraryName": args.native_library_name
        or loaded.get("nativeLibraryName")
        or DEFAULTS["nativeLibraryName"],
        "goObfuscationSeed": args.go_obfuscation_seed
        or loaded.get("goObfuscationSeed")
        or loaded.get("obfuscationSeed")
        or secrets.token_hex(16),
        "denylistVersion": (
            args.denylist_version
            if args.denylist_version is not None
            else loaded.get("denylistVersion", DEFAULTS["denylistVersion"])
        ),
    }

    for key, value in loaded.items():
        profile.setdefault(key, value)

    return validate_profile(profile)


def dart_defines(profile: dict[str, Any]) -> dict[str, str]:
    return {define: str(profile[key]) for key, define in DART_DEFINE_KEYS.items()}


def artifact_metadata(profile: dict[str, Any]) -> dict[str, Any]:
    metadata = {
        key: value for key, value in profile.items() if key != "goObfuscationSeed"
    }
    metadata["goObfuscationSeedSha256"] = hashlib.sha256(
        str(profile["goObfuscationSeed"]).encode("utf-8")
    ).hexdigest()
    return metadata


def go_tags_suffix(profile: dict[str, Any]) -> str:
    mode_tag = str(profile["mode"]).replace("-", "_")
    return f",stealth,{mode_tag}"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="optional input profile JSON")
    parser.add_argument("--output", type=Path, help="normalized profile output path")
    parser.add_argument("--dart-defines-output", type=Path)
    parser.add_argument("--artifact-metadata-output", type=Path)
    parser.add_argument("--go-tags-suffix", action="store_true")
    parser.add_argument("--mode", choices=VALID_MODES)
    parser.add_argument("--package-name")
    parser.add_argument("--app-name")
    parser.add_argument("--session-name")
    parser.add_argument("--native-library-name")
    parser.add_argument("--go-obfuscation-seed")
    parser.add_argument("--denylist-version", type=int)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        profile = (
            validate_profile(load_json(args.input))
            if args.go_tags_suffix
            else build_profile(args)
        )
        if args.go_tags_suffix:
            print(go_tags_suffix(profile), end="")
            return 0
        if not args.output:
            raise ProfileError("--output is required when generating a profile")
        write_json(args.output, profile)
        if args.dart_defines_output:
            write_json(args.dart_defines_output, dart_defines(profile))
        if args.artifact_metadata_output:
            write_json(args.artifact_metadata_output, artifact_metadata(profile))
        print(f"Wrote stealth profile: {args.output}")
        return 0
    except ProfileError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
