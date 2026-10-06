#!/usr/bin/env python3
"""Prepare and verify failure scenarios on dedicated desktop update CI runners."""

import argparse
import json
import os
from pathlib import Path


SCENARIOS = ("baseline", "core-unavailable")
STAGING_FEED = (
    "https://update.staging.iantem.io/update/lantern/appcast.xml?channel=beta"
)


def validate_target(scenario, target):
    if scenario not in SCENARIOS:
        raise ValueError(f"Unknown update scenario: {scenario}")
    if target["appcast_url"] != STAGING_FEED:
        raise ValueError(f"{scenario} requires {STAGING_FEED}")


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "verify"))
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
    if args.target is None or args.output is None:
        parser.error("--target and --output are required")
    target = json.loads(args.target.read_text(encoding="utf-8-sig"))
    validate_target(args.scenario, target)
    evidence = {"scenario": args.scenario, "appcast_url": target["appcast_url"]}
    if args.command == "verify":
        if args.handoff is None:
            parser.error("--handoff is required")
        handoff = json.loads(args.handoff.read_text(encoding="utf-8-sig"))
        verify_handoff(args.scenario, target, handoff)
        evidence["handoff"] = handoff
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
