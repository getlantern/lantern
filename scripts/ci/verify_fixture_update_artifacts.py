#!/usr/bin/env python3
"""Verify signed desktop fixture artifacts and their update sidecars."""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import tempfile
import urllib.parse


class VerificationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def public_key(info_plist: pathlib.Path, runner_rc: pathlib.Path) -> bytes:
    with info_plist.open("rb") as source:
        mac_key = plistlib.load(source).get("SUPublicEDKey", "")
    match = re.search(
        r'EdDSAPub\s+EDDSA\s+\{"([A-Za-z0-9+/=]+)"\}',
        runner_rc.read_text(encoding="utf-8"),
    )
    require(match is not None, "Windows EdDSAPub resource is missing")
    windows_key = match.group(1)
    require(mac_key == windows_key, "macOS and Windows update public keys differ")
    try:
        decoded = base64.b64decode(mac_key, validate=True)
    except (binascii.Error, ValueError) as err:
        raise VerificationError("update public key is not valid base64") from err
    require(len(decoded) == 32, "Ed25519 public key must decode to 32 bytes")
    return decoded


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_signature(artifact: pathlib.Path, signature: str, key: bytes) -> None:
    try:
        decoded_signature = base64.b64decode(signature, validate=True)
    except (binascii.Error, ValueError) as err:
        raise VerificationError(f"invalid signature for {artifact.name}") from err
    require(len(decoded_signature) == 64, f"invalid signature length for {artifact.name}")

    # SubjectPublicKeyInfo prefix for a raw Ed25519 public key (RFC 8410).
    spki = bytes.fromhex("302a300506032b6570032100") + key
    with tempfile.TemporaryDirectory() as temporary_directory:
        temporary = pathlib.Path(temporary_directory)
        key_path = temporary / "public-key.der"
        signature_path = temporary / "signature.bin"
        key_path.write_bytes(spki)
        signature_path.write_bytes(decoded_signature)
        result = subprocess.run(
            [
                "openssl",
                "pkeyutl",
                "-verify",
                "-pubin",
                "-inkey",
                str(key_path),
                "-keyform",
                "DER",
                "-rawin",
                "-in",
                str(artifact),
                "-sigfile",
                str(signature_path),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
    require(
        result.returncode == 0,
        f"Ed25519 verification failed for {artifact.name}: "
        f"{result.stderr.strip() or result.stdout.strip()}",
    )


def verify_sidecar(
    sidecar: pathlib.Path,
    artifact_directory: pathlib.Path,
    asset_base_url: str,
    key: bytes,
) -> None:
    metadata = json.loads(sidecar.read_text(encoding="utf-8"))
    filename = metadata.get("filename", "")
    require(isinstance(filename, str) and bool(filename), f"invalid filename in {sidecar.name}")
    artifact = artifact_directory / filename
    require(artifact.is_file(), f"artifact is missing for {sidecar.name}: {filename}")
    require(metadata.get("size") == artifact.stat().st_size, f"size mismatch for {filename}")
    require(metadata.get("sha256") == sha256(artifact), f"checksum mismatch for {filename}")
    expected_url = f"{asset_base_url.rstrip('/')}/{urllib.parse.quote(filename)}"
    require(metadata.get("url") == expected_url, f"unexpected fixture URL for {filename}")
    sparkle_version = str(metadata.get("sparkle_version", ""))
    require(
        sparkle_version.isascii() and sparkle_version.isdigit(),
        f"invalid Sparkle version for {filename}",
    )
    verify_signature(artifact, metadata.get("sparkle_ed_signature", ""), key)
    print(f"verified {filename}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", required=True, type=pathlib.Path)
    parser.add_argument("--metadata-dir", required=True, type=pathlib.Path)
    parser.add_argument("--asset-base-url", required=True)
    parser.add_argument("--info-plist", default="macos/Runner/Info.plist", type=pathlib.Path)
    parser.add_argument("--runner-rc", default="windows/runner/Runner.rc", type=pathlib.Path)
    args = parser.parse_args()

    try:
        key = public_key(args.info_plist, args.runner_rc)
        sidecars = sorted(args.metadata_dir.glob("*.update.json"))
        require(bool(sidecars), "no fixture sidecars found")
        for sidecar in sidecars:
            verify_sidecar(sidecar, args.artifact_dir, args.asset_base_url, key)
    except (OSError, VerificationError, json.JSONDecodeError) as err:
        raise SystemExit(f"fixture verification failed: {err}") from err


if __name__ == "__main__":
    main()
