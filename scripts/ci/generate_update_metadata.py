#!/usr/bin/env python3
"""Generate Lantern update metadata sidecars for release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Optional, Tuple


SPARKLE_SIGNATURE_RE = re.compile(r'sparkle:edSignature="([^"]+)"')


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


def sparkle_signature(path: Path) -> str:
    # Lantern CI owns Sparkle signing. lantern-cloud only reads this value back
    # from the sidecar when it renders the channel appcast.
    proc = subprocess.run(
        ["dart", "run", "auto_updater:sign_update", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    match = SPARKLE_SIGNATURE_RE.search(proc.stdout.strip())
    if not match:
        raise RuntimeError(f"could not parse Sparkle signature for {path.name}: {proc.stdout}")
    return match.group(1)


def sidecar_for(path: Path, build_type: str, version: str, bucket: str) -> Optional[dict[str, object]]:
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
    if platform in ("macos", "windows"):
        metadata["sparkle_ed_signature"] = sparkle_signature(path)
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-type", required=True)
    parser.add_argument("--version", required=True, help="Release version without leading v")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("artifacts", nargs="+", type=Path)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    generated = 0
    for artifact in args.artifacts:
        if not artifact.is_file():
            continue
        metadata = sidecar_for(artifact, args.build_type, args.version, args.bucket)
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
