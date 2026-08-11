#!/usr/bin/env python3
"""Generate Lantern update metadata sidecars for release artifacts."""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
from pathlib import Path
from typing import Optional, Tuple


def release_channel(build_type: str) -> str:
    normalized = build_type.strip().lower()
    if normalized in ("production", "prod", "stable", ""):
        return "stable"
    if normalized == "beta":
        return "beta"
    if normalized in ("nightly", "internal", "dev", "development"):
        return "nightly"
    raise ValueError(f"unsupported build type: {build_type}")


def artifact_info(filename: str) -> Optional[Tuple[str, str, str]]:
    # Keep this in step with lantern-cloud's installer matcher. We do ship
    # RPM/Arch/IPA artifacts, but the update service can't safely pick those
    # formats from today's os/arch-only update request.
    if filename.endswith(".dmg"):
        return "macos", "darwin", "amd64"
    if filename.endswith(".exe"):
        return "windows", "windows", "amd64"
    if filename.endswith(".apk"):
        return "android", "android", "arm"
    if filename.endswith(".deb"):
        arch = "arm64" if filename.endswith("-arm64.deb") else "amd64"
        return "linux", "linux", arch
    return None


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _der_value(data: bytes, offset: int, expected_tag: int) -> tuple[bytes, int]:
    """Read one definite-length DER value and return its contents and end offset."""
    if offset >= len(data) or data[offset] != expected_tag:
        raise ValueError("unexpected DER tag")
    offset += 1
    if offset >= len(data):
        raise ValueError("missing DER length")

    first_length_byte = data[offset]
    offset += 1
    if first_length_byte < 0x80:
        length = first_length_byte
    else:
        length_byte_count = first_length_byte & 0x7F
        if (
            length_byte_count == 0
            or offset + length_byte_count > len(data)
            or data[offset] == 0
        ):
            raise ValueError("invalid DER length")
        length = int.from_bytes(data[offset : offset + length_byte_count], "big")
        if length < 0x80:
            raise ValueError("non-minimal DER length")
        offset += length_byte_count

    end = offset + length
    if end > len(data):
        raise ValueError("truncated DER value")
    return data[offset:end], end


def _is_valid_dsa_signature(signature: bytes) -> bool:
    """Return whether a signature is one DER sequence of two positive integers."""
    try:
        sequence, end = _der_value(signature, 0, 0x30)
        if end != len(signature):
            return False
        r_value, offset = _der_value(sequence, 0, 0x02)
        s_value, offset = _der_value(sequence, offset, 0x02)
        if offset != len(sequence):
            return False
    except ValueError:
        return False

    for value in (r_value, s_value):
        if not value or not any(value) or value[0] & 0x80:
            return False
        if len(value) > 1 and value[0] == 0 and not value[1] & 0x80:
            return False
    return True


def updater_signature(path: Path, signature_dir: Path, kind: str) -> str:
    # Signing happens on the native platform build runners. This Linux job only
    # validates and packages their public signatures into release sidecars.
    signature_path = signature_dir / f"{path.name}.sparkle-signature"
    try:
        signature = signature_path.read_text(encoding="ascii").strip()
    except FileNotFoundError as err:
        raise RuntimeError(f"missing {kind} signature for {path.name}") from err

    try:
        decoded = base64.b64decode(signature, validate=True)
    except (binascii.Error, ValueError) as err:
        raise RuntimeError(f"invalid {kind} signature for {path.name}") from err
    if kind == "EdDSA" and len(decoded) != 64:
        raise RuntimeError(f"invalid EdDSA signature length for {path.name}")
    if kind == "DSA" and not _is_valid_dsa_signature(decoded):
        raise RuntimeError(f"invalid DSA signature for {path.name}")
    return signature


def sidecar_for(
    path: Path,
    build_type: str,
    version: str,
    bucket: str,
    signature_dir: Optional[Path] = None,
    sparkle_version: Optional[str] = None,
) -> Optional[dict[str, object]]:
    info = artifact_info(path.name)
    if info is None:
        return None

    platform, os_name, arch = info
    channel = release_channel(build_type)
    url = f"https://s3.amazonaws.com/{bucket}/releases/{build_type}/{version}/{path.name}"
    metadata: dict[str, object] = {
        "schema_version": 1,
        "app": "lantern",
        "version": version,
        "short_version": version.split("-", 1)[0],
        "channel": channel,
        "build_type": build_type,
        "platform": platform,
        "os": os_name,
        "arch": arch,
        "filename": path.name,
        "url": url,
        "size": path.stat().st_size,
        "sha256": sha256_file(path),
    }
    if platform == "macos":
        if not sparkle_version:
            raise RuntimeError(f"missing Sparkle version for {path.name}")
        if signature_dir is None:
            raise RuntimeError(f"missing signature directory for {path.name}")
        metadata["sparkle_version"] = sparkle_version
        metadata["sparkle_ed_signature"] = updater_signature(path, signature_dir, "EdDSA")
    elif platform == "windows":
        if not sparkle_version:
            raise RuntimeError(f"missing Sparkle version for {path.name}")
        if signature_dir is None:
            raise RuntimeError(f"missing signature directory for {path.name}")
        metadata["sparkle_version"] = sparkle_version
        metadata["sparkle_dsa_signature"] = updater_signature(path, signature_dir, "DSA")
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-type", required=True)
    parser.add_argument("--version", required=True, help="Release version without leading v")
    parser.add_argument("--sparkle-version", required=True, help="Desktop bundle build number")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--sparkle-signature-dir", required=True, type=Path)
    parser.add_argument("artifacts", nargs="+", type=Path)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    generated = 0
    for artifact in args.artifacts:
        if not artifact.is_file():
            continue
        metadata = sidecar_for(
            artifact,
            args.build_type,
            args.version,
            args.bucket,
            args.sparkle_signature_dir,
            args.sparkle_version,
        )
        if metadata is None:
            continue
        output = args.output_dir / f"{artifact.name}.update.json"
        with output.open("w", encoding="utf-8") as fp:
            json.dump(metadata, fp, indent=2, sort_keys=True)
            fp.write("\n")
        generated += 1
        print(f"generated {output}")

    if generated == 0:
        raise SystemExit("no update metadata sidecars generated")


if __name__ == "__main__":
    main()
