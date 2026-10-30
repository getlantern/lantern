#!/usr/bin/env python3
"""Assemble a pinned migration bundle on Windows; do not publish or enable updates."""
import argparse
import bz2
import json
from pathlib import Path, PureWindowsPath
import shutil
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit
from urllib.request import urlopen
import zipfile

import bundle

MAX_BUNDLE_BYTES = 4 << 30


def fetch(source, destination):
    bundle.require(isinstance(source, str) and bool(source), "invalid_source")
    url = urlsplit(source)
    remote = url.scheme == "https"
    bundle.require(not url.username and not url.password and not url.fragment, "invalid_source")
    if "://" in source:
        bundle.require(remote and bool(url.hostname), "https_source_required")
    compressed = (url.path if remote else source).endswith(".bz2")
    with (urlopen(source, timeout=120) if remote else Path(source).open("rb")) as raw:
        if remote:
            bundle.require(urlsplit(raw.geturl()).scheme == "https", "insecure_redirect")
        with (bz2.open(raw, "rb") if compressed else raw) as content, destination.open("xb") as target:
            while block := content.read(1024 * 1024):
                bundle.require(target.tell() + len(block) <= MAX_BUNDLE_BYTES, "asset_too_large")
                target.write(block)


def verify_signatures(root, manifest):
    # JSON over stdin keeps paths out of PowerShell source and error messages.
    script = r"""
    $ErrorActionPreference = 'Stop'
    try {
      $assets = [Console]::In.ReadToEnd() | ConvertFrom-Json
      foreach ($asset in $assets) {
        $signature = Get-AuthenticodeSignature -LiteralPath $asset.path
        if ($signature.Status -ne 'Valid' -or
            $signature.SignerCertificate.Thumbprint -ine $asset.signer) { exit 1 }
      }
    } catch { exit 1 }
    """
    assets = [{"path": str(root / asset["file"]), "signer": asset["signer_thumbprint"]}
              for asset in manifest["artifacts"].values() if "signer_thumbprint" in asset]
    subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
                   input=json.dumps(assets), text=True, capture_output=True, timeout=180, check=True)


def assemble(manifest_path, manifest_hash, sources, output):
    bundle.require(sys.platform == "win32", "windows_signature_verification_required")
    bundle.require(bundle.HEX64.fullmatch(manifest_hash) and bundle.sha256(manifest_path) == manifest_hash,
                   "manifest_hash_mismatch")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    bundle.require(set(sources) == set(manifest["artifacts"]), "source_set")
    names = [asset["file"] for asset in manifest["artifacts"].values()]
    bundle.require(len(set(names)) == len(names) and "manifest.json" not in names, "duplicate_asset")
    for name in names:
        bundle.require(isinstance(name, str) and name not in {"", ".", ".."} and
                       Path(name).name == name and PureWindowsPath(name).name == name and ":" not in name,
                       "flat_asset_required")
    output = output.resolve()
    metadata_path = output.with_suffix(".json")
    bundle.require(output.suffix == ".zip" and not output.exists() and not metadata_path.exists(),
                   "fresh_output_required")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="migration-bundle-", dir=output.parent) as scratch:
        root = Path(scratch)
        shutil.copyfile(manifest_path, root / "manifest.json")
        for role, source in sources.items():
            asset = manifest["artifacts"][role]
            target = root / asset["file"]
            fetch(source, target)
            bundle.require(bundle.sha256(target) == asset["sha256"], "asset_hash_mismatch")
        bundle.require(sum(path.stat().st_size for path in root.iterdir()) <= MAX_BUNDLE_BYTES,
                       "bundle_too_large")
        manifest = bundle.validate(root, manifest_hash)
        bundle.verify_binary_builds(root, manifest)
        verify_signatures(root, manifest)
        # Only manifest-listed bytes enter the flat archive; private fixtures and
        # credentials cannot be included by a broad directory/glob upload.
        with output.open("xb") as stream, zipfile.ZipFile(stream, "w", zipfile.ZIP_DEFLATED) as archive:
            for name in ["manifest.json", *sorted(names)]:
                archive.write(root / name, name)
    result = {"run_id": manifest["run_id"], "lane": manifest["lane"],
              "manifest_sha256": manifest_hash, "bundle_sha256": bundle.sha256(output),
              "lantern_sha": manifest["source_commits"]["lantern"],
              "cloud_sha": manifest["source_commits"]["lantern-cloud"],
              "production_activation_ready": False}
    with metadata_path.open("x", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--sources", type=Path, required=True,
                        help="JSON object mapping each artifact role to its local path or HTTPS URL")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        sources = json.loads(args.sources.read_text(encoding="utf-8-sig"))
        print(json.dumps(assemble(args.manifest, args.manifest_sha256, sources, args.output)))
        return 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError):
        print('{"ok":false,"code":"bundle_preparation_failed"}')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
