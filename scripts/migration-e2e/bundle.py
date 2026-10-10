#!/usr/bin/env python3
"""Validate a reviewed, local staging migration bundle. Never fetch or run assets."""
import argparse
import hashlib
import json
from pathlib import Path, PureWindowsPath
import re
import shlex
import struct
import subprocess

ENDPOINT = "https://update.staging.iantem.io/update/lantern"
CATALOG = "getlantern/lantern-update-fixtures"
SEED_COMMIT = "1145e4ca7a7d1d5bfb7b4cd9cdb719a7aaea202e"
HEX64 = re.compile(r"[a-f0-9]{64}\Z")


def require(condition, code):
    if not condition:
        raise ValueError(code)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def local_file(root, name):
    require(isinstance(name, str) and bool(name), "invalid_asset_path")
    win = PureWindowsPath(name)
    require(not win.drive and not win.root and ".." not in win.parts
            and ":" not in name and "\\" not in name, "invalid_asset_path")
    path = root / name
    require(path.resolve().is_relative_to(root.resolve()), "asset_outside_bundle")
    require(not any(p.is_symlink() for p in [path, *path.parents] if p != root.parent),
            "symlink_asset")
    require(path.is_file(), "missing_asset")
    return path


def pe_machine(path):
    with path.open("rb") as stream:
        require(stream.read(2) == b"MZ", "invalid_pe")
        stream.seek(60)
        raw = stream.read(4)
        require(len(raw) == 4, "invalid_pe")
        offset = struct.unpack("<I", raw)[0]
        require(64 <= offset <= path.stat().st_size - 6, "invalid_pe")
        stream.seek(offset)
        require(stream.read(4) == b"PE\0\0", "invalid_pe")
        return struct.unpack("<H", stream.read(2))[0]


def verify_legacy_build(info, role, commit, version):
    """Check metadata read directly from the EXE, including after Authenticode signing."""
    require(info.splitlines() and info.splitlines()[0].endswith(": go1.22.4"), "legacy_toolchain")
    require("\tpath\tgithub.com/getlantern/lantern-desktop/main" in info, "legacy_package")
    settings = {}
    for line in info.splitlines()[1:]:
        parts = shlex.split(line)
        if len(parts) == 2 and parts[0] == "build" and "=" in parts[1]:
            key, value = parts[1].split("=", 1)
            require(key not in settings, "duplicate_build_setting")
            settings[key] = value
    for key, value in {"GOOS": "windows", "GOARCH": "386", "vcs.revision": commit, "vcs.modified": "false"}.items():
        require(settings.get(key) == value, "legacy_build_setting")
    tags = {"lantern", "walk_use_cgo"} | ({"migratione2e"} if role == "bridge" else set())
    require(set(re.split("[, ]+", settings.get("-tags", ""))) == tags, "legacy_build_tags")
    prefix = "github.com/getlantern/lantern-desktop/"
    expected = {"github.com/getlantern/flashlight/v7/common.ProAPIHost": "api-staging.getiantem.org",
                prefix + "desktop.ApplicationVersion": version}
    if role == "bridge":
        expected[prefix + "autoupdate.WindowsInstallerHandoff"] = "1"
    optional = {prefix + "desktop.BuildDate", prefix + "desktop.RevisionDate"}
    overrides = {}
    flags = iter(shlex.split(settings.get("-ldflags", "")))
    for flag in flags:
        if flag == "-X":
            raw = next(flags, "")
            require("=" in raw, "legacy_linker_value")
            key, value = raw.split("=", 1)
            require(key not in overrides and key in (set(expected) | optional), "legacy_linker_override")
            overrides[key] = value
        else:
            require(flag in {"-s", "-w", "-H=windowsgui"}, "legacy_linker_flag")
    require(all(overrides.get(k) == v for k, v in expected.items()), "legacy_endpoint_or_version")
    for key in optional & overrides.keys():
        require(bool(re.fullmatch(r"[0-9T:Z.+-]{1,64}", overrides[key])), "legacy_build_date")


def verify_binary_builds(root, manifest):
    for role in ("seed", "bridge"):
        exe = local_file(root, manifest["artifacts"][role]["file"])
        # go version inspects the binary; it does not execute it. Do not accept a
        # text descriptor as proof of the executable's account endpoint or source.
        result = subprocess.run(["go", "version", "-m", str(exe)], capture_output=True,
                                text=True, encoding="utf-8", timeout=30, check=True)
        verify_legacy_build(result.stdout, role,
                            manifest["source_commits"]["seed" if role == "seed" else "lantern-desktop"],
                            "7.9.5" if role == "seed" else manifest["bridge_version"])


def validate(root, manifest_hash):
    require(bool(HEX64.fullmatch(manifest_hash)), "invalid_manifest_hash")
    path = local_file(root, "manifest.json")
    require(sha256(path) == manifest_hash, "manifest_hash_mismatch")
    m = json.loads(path.read_text(encoding="utf-8-sig"))
    require(set(m) == {"schema_version", "run_id", "lane", "scenario", "endpoint", "catalog",
                       "source_commits", "artifacts", "bridge_version", "installer_version",
                       "probe_url", "account_environment", "production_activation_ready"}, "manifest_fields")
    require(m["schema_version"] == 1 and m["production_activation_ready"] is False, "manifest_version")
    require(m["lane"] == "rebuilt-staging", "released_binary_account_isolation_blocked")
    require(m["scenario"] in {"success", "cancel", "installer-failure"}, "invalid_scenario")
    require(bool(re.fullmatch(r"[a-f0-9]{32}", m["run_id"])), "invalid_run_id")
    require(m["endpoint"] == ENDPOINT and m["catalog"] == CATALOG
            and m["account_environment"] == "staging", "not_isolated_staging")
    require(bool(re.fullmatch(r"7\.(0|[1-9]\d*)\.(0|[1-9]\d*)", m["bridge_version"]))
            and tuple(map(int, m["bridge_version"].split("."))) > (7, 9, 5), "invalid_bridge_version")
    require(bool(re.fullmatch(r"10\.(0|[1-9]\d*)\.(0|[1-9]\d*)", m["installer_version"])), "invalid_installer_version")
    from urllib.parse import urlsplit
    url = urlsplit(m["probe_url"])
    require(url.scheme == "https" and url.hostname and not url.username and not url.password
            and not url.query and not url.fragment, "invalid_connectivity_url")
    require(set(m["source_commits"]) == {"seed", "lantern", "lantern-desktop", "radiance", "lantern-cloud"}, "source_commits")
    require(all(isinstance(v, str) and re.fullmatch(r"[a-f0-9]{40}", v)
                for v in m["source_commits"].values()), "source_commits")
    require(m["source_commits"]["seed"] == SEED_COMMIT, "wrong_seed_source")
    artifacts = m["artifacts"]
    require(set(artifacts) == {"seed", "bridge", "installer", "probe", "global_checker", "global_config"}, "asset_set")
    for name, asset in artifacts.items():
        expected = {"file", "sha256"} | ({"signer_thumbprint"} if name in {"seed", "bridge", "installer"} else set())
        require(set(asset) == expected, "asset_fields")
        require(bool(HEX64.fullmatch(asset["sha256"])), "invalid_asset_hash")
        file = local_file(root, asset["file"])
        require(sha256(file) == asset["sha256"], "asset_hash_mismatch")
        if "signer_thumbprint" in asset:
            require(bool(re.fullmatch(r"[A-Fa-f0-9]{40}", asset["signer_thumbprint"])), "invalid_signer")
        if name in {"seed", "bridge", "probe", "global_checker"}:
            require(pe_machine(file) == (0x14C if name != "probe" else 0x8664), "wrong_pe_arch")
    # Use JSON (a YAML subset) to avoid ambiguous/duplicate YAML keys and keep the
    # seed's sticky config inspectable. The application still reads real global.yaml.
    config = json.loads(local_file(root, artifacts["global_config"]["file"]).read_text(encoding="utf-8"))
    require(config.get("updateserverurl") == "https://update.staging.iantem.io", "wrong_global_endpoint")
    require(isinstance(config.get("autoupdateca"), str)
            and config["autoupdateca"].startswith("-----BEGIN CERTIFICATE-----"), "missing_update_ca")
    require(isinstance(config.get("trustedcas"), list) and bool(config["trustedcas"]), "missing_trusted_cas")
    require(isinstance(config.get("client"), dict)
            and config["client"].get("fronted", {}).get("providers"), "missing_fronted_providers")
    # The Windows runner also invokes the companion's validator, compiled against
    # the frozen legacy config decoder/types. Structural checks alone cannot prove
    # the old app will accept global.yaml instead of its embedded fallback.
    return m


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--manifest-sha256", required=True)
    args = parser.parse_args()
    try:
        m = validate(args.bundle, args.manifest_sha256)
        verify_binary_builds(args.bundle, m)
        print(json.dumps({"ok": True, "schema_version": 1, "run_id": m["run_id"],
                          "lane": m["lane"], "scenario": m["scenario"], "production_activation_ready": False}))
        return 0
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError):
        # A malformed bundle must not put arbitrary data or paths in uploaded logs.
        print('{"ok":false,"code":"invalid_bundle"}')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
