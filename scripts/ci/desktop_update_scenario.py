#!/usr/bin/env python3
"""Prepare and verify failure scenarios on dedicated desktop update CI runners."""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import posixpath
import socket
import subprocess
import sys
from urllib.parse import urlsplit


SCENARIOS = ("baseline", "core-unavailable", "core-unavailable-direct-blocked")
PRODUCTION_FEED = (
    "https://update.getlantern.org/update/lantern/appcast.xml?channel=beta"
)
STAGING_FEED = (
    "https://update.staging.iantem.io/update/lantern/appcast.xml?channel=beta"
)
BLOCKED_HOSTS = (
    "update.getlantern.org",
    "s3.amazonaws.com",
    "s3.us-east-1.amazonaws.com",
    "lantern.io.s3.amazonaws.com",
    "lantern.io.s3.us-east-1.amazonaws.com",
)
MARKER = "# lantern-auto-update-smoke"


def validate_target(scenario, target):
    if scenario not in SCENARIOS:
        raise ValueError(f"Unknown update scenario: {scenario}")
    blocked = scenario == SCENARIOS[2]
    expected_feed = PRODUCTION_FEED if blocked else STAGING_FEED
    if target["appcast_url"] != expected_feed:
        raise ValueError(f"{scenario} requires {expected_feed}")
    if blocked:
        artifact = urlsplit(target["artifact_url"])
        prefix = {
            "update.getlantern.org": "/releases/",
            "s3.amazonaws.com": "/lantern.io/releases/",
            "s3.us-east-1.amazonaws.com": "/lantern.io/releases/",
        }.get(artifact.netloc)
        if (
            artifact.scheme != "https"
            or prefix is None
            or artifact.query
            or artifact.fragment
            or not artifact.path.startswith(prefix)
            or posixpath.normpath(artifact.path) != artifact.path
            or "%" in artifact.path
            or not artifact.path.endswith((".dmg", ".exe"))
        ):
            raise ValueError(
                "Blocked scenario requires a published beta installer under the update/S3 releases path"
            )


def edit_hosts(path, block):
    # Keep unrelated entries and the file's owner/ACLs intact, including on cleanup.
    with path.open("r+", encoding="utf-8", newline="") as hosts_file:
        original = hosts_file.read()
        clean = "".join(
            line
            for line in original.splitlines(keepends=True)
            if not line.rstrip().endswith(MARKER)
        )
        updated = clean
        if block:
            if updated and not updated.endswith("\n"):
                updated += "\n"
            updated += "".join(
                f"{address} {host} {MARKER}\n"
                for host in BLOCKED_HOSTS
                for address in ("127.0.0.1", "::1")
            )
        if updated != original:
            hosts_file.seek(0)
            hosts_file.write(updated)
            hosts_file.truncate()
            hosts_file.flush()
            os.fsync(hosts_file.fileno())


def require_blocked_dns():
    resolved = {}
    for host in BLOCKED_HOSTS:
        addresses = sorted(
            {
                entry[4][0]
                for entry in socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM)
            }
        )
        if not addresses or any(
            not ipaddress.ip_address(address).is_loopback for address in addresses
        ):
            raise ValueError(f"Direct access is not blocked for {host}: {addresses}")
        resolved[host] = addresses
    return resolved


def verify_handoff(scenario, target, handoff):
    validate_target(scenario, target)
    expected = {
        "scenario": scenario,
        "feed_url": target["appcast_url"],
        "build_number": str(target["fixture_build"]),
        "display_version": target["display_version"],
        "update_offered": True,
        "core_initialization_held": scenario != "baseline",
        "core_ready": scenario == "baseline",
    }
    for key, value in expected.items():
        if (
            key not in handoff
            or type(handoff[key]) is not type(value)
            or handoff[key] != value
        ):
            raise ValueError(
                f"Handoff {key} must be {value!r}; got {handoff.get(key)!r}"
            )
    if type(handoff.get("pid")) is not int or handoff["pid"] <= 0:
        raise ValueError("Handoff has no valid source process")


def flush_dns():
    commands = (
        [["ipconfig", "/flushdns"]]
        if sys.platform == "win32"
        else [["dscacheutil", "-flushcache"], ["killall", "-HUP", "mDNSResponder"]]
    )
    for command in commands:
        subprocess.run(command, check=True, timeout=15)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "block", "restore", "verify"))
    parser.add_argument("--scenario", choices=SCENARIOS, default="baseline")
    parser.add_argument("--target", type=Path)
    parser.add_argument("--handoff", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    if any(
        os.environ.get(key) != "true"
        for key in ("CI", "GITHUB_ACTIONS", "LANTERN_AUTO_UPDATE_SMOKE")
    ):
        parser.error(
            "This helper requires the explicit GitHub Actions update smoke guard"
        )
    if args.command in ("block", "restore"):
        if sys.platform == "darwin":
            if os.environ.get("RUNNER_ENVIRONMENT") != "self-hosted":
                parser.error(
                    "macOS network changes require the dedicated self-hosted runner"
                )
            hosts = Path("/etc/hosts")
        elif sys.platform == "win32":
            hosts = Path(os.environ["SystemRoot"]) / "System32/drivers/etc/hosts"
        else:
            parser.error("Network changes are desktop-only")
        if args.command == "restore":
            edit_hosts(hosts, False)
            flush_dns()
            return
        if args.scenario != SCENARIOS[2]:
            parser.error("Only the blocked scenario may change DNS")

    if args.target is None or args.output is None:
        parser.error("--target and --output are required")
    target = json.loads(args.target.read_text(encoding="utf-8-sig"))
    validate_target(args.scenario, target)
    evidence = {"scenario": args.scenario, "appcast_url": target["appcast_url"]}
    if args.command == "block":
        edit_hosts(hosts, True)
        flush_dns()
        evidence["blocked_dns"] = require_blocked_dns()
    elif args.command == "verify":
        if args.handoff is None:
            parser.error("--handoff is required")
        handoff = json.loads(args.handoff.read_text(encoding="utf-8-sig"))
        verify_handoff(args.scenario, target, handoff)
        evidence["handoff"] = handoff
        if args.scenario == SCENARIOS[2]:
            evidence["blocked_dns"] = require_blocked_dns()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
