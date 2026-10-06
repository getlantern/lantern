#!/usr/bin/env python3
"""Assemble local catalog assets from a reviewed signed bundle; never publish."""
import argparse
import bz2
import json
from pathlib import Path
import shutil

import bundle


def assemble(root, digest, output):
    m = bundle.validate(root, digest)
    bundle.verify_binary_builds(root, m)
    # A fresh output prevents accidental replacement of a previous fixture's bytes.
    output.mkdir(parents=True, exist_ok=False)
    bridge_dir = output / ("v" + m["bridge_version"])
    installer_dir = output / ("v" + m["installer_version"])
    bridge_dir.mkdir()
    installer_dir.mkdir()
    source = bundle.local_file(root, m["artifacts"]["bridge"]["file"])
    target = bridge_dir / ("update_windows_386_" + m["bridge_version"] + ".bz2")
    with source.open("rb") as raw, bz2.open(target, "wb", compresslevel=9) as compressed:
        shutil.copyfileobj(raw, compressed)
    shutil.copyfile(bundle.local_file(root, m["artifacts"]["installer"]["file"]), installer_dir / "lantern-installer.exe")
    (output / "catalog.json").write_text(json.dumps({
        "schema_version": 1, "catalog": bundle.CATALOG, "manifest_sha256": digest,
        "bridge_version": m["bridge_version"], "installer_version": m["installer_version"],
        "bridge_raw_sha256": m["artifacts"]["bridge"]["sha256"],
        "installer_sha256": m["artifacts"]["installer"]["sha256"],
        "production_activation_ready": False,
    }, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assemble(args.bundle, args.manifest_sha256, args.output)
