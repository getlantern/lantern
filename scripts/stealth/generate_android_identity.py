#!/usr/bin/env python3
"""Generate Android identity profiles for Stealth builds."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import secrets
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


ADJECTIVES = (
    "Clear",
    "Bright",
    "Quiet",
    "Swift",
    "Plain",
    "Fresh",
    "Daily",
    "Open",
    "Simple",
    "Calm",
    "True",
    "Soft",
)

NOUNS = (
    "Notes",
    "Tasks",
    "Pages",
    "Files",
    "Board",
    "List",
    "Desk",
    "Folder",
    "Memo",
    "Panel",
    "Space",
    "Stack",
)

PACKAGE_ROOTS = (
    "app",
    "tools",
    "pages",
    "notes",
    "desk",
    "files",
)

ANDROID_APPLICATION_ID = re.compile(
    r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$"
)


@dataclass(frozen=True)
class AndroidIdentity:
    application_id: str
    app_label: str
    launcher_label: str
    identity_label: str
    identity_profile_id: str
    identity_metadata: str
    vpn_session_name: str
    notification_channel_vpn: str
    notification_channel_data_usage: str
    notification_title: str
    notification_connected_text: str
    notification_starting_text: str
    notification_disconnect_action: str
    quick_tile_active_label: str
    quick_tile_inactive_label: str
    app_icon: str
    app_round_icon: str
    notification_small_icon: str
    quick_tile_icon: str
    app_auth_scheme: str

    def as_properties(self) -> dict[str, str]:
        return {
            "applicationId": self.application_id,
            "appLabel": self.app_label,
            "launcherLabel": self.launcher_label,
            "identityLabel": self.identity_label,
            "identityProfileId": self.identity_profile_id,
            "identityMetadata": self.identity_metadata,
            "vpnSessionName": self.vpn_session_name,
            "notificationChannelVpn": self.notification_channel_vpn,
            "notificationChannelDataUsage": self.notification_channel_data_usage,
            "notificationTitle": self.notification_title,
            "notificationConnectedText": self.notification_connected_text,
            "notificationStartingText": self.notification_starting_text,
            "notificationDisconnectAction": self.notification_disconnect_action,
            "quickTileActiveLabel": self.quick_tile_active_label,
            "quickTileInactiveLabel": self.quick_tile_inactive_label,
            "appIcon": self.app_icon,
            "appRoundIcon": self.app_round_icon,
            "notificationSmallIcon": self.notification_small_icon,
            "quickTileIcon": self.quick_tile_icon,
            "appAuthScheme": self.app_auth_scheme,
        }


def _slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def _token(rng: random.Random, size: int = 8) -> str:
    alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    return rng.choice("abcdefghijklmnopqrstuvwxyz") + "".join(
        rng.choice(alphabet) for _ in range(size - 1)
    )


def _seed_material(seed: str | None) -> tuple[str, bool]:
    if seed:
        return seed, False
    return secrets.token_hex(32), True


def generate_identity(
    seed: str | None = None,
    package_root: str | None = None,
    app_icon: str = "@drawable/neutral_app_icon",
    app_round_icon: str = "@drawable/neutral_app_icon",
    notification_small_icon: str = "@drawable/neutral_notification_icon",
    quick_tile_icon: str = "@drawable/neutral_notification_icon",
) -> AndroidIdentity:
    seed_value, random_seed = _seed_material(seed)
    digest = hashlib.sha256(seed_value.encode("utf-8")).hexdigest()
    rng = random.Random(digest)

    adjective = rng.choice(ADJECTIVES)
    noun = rng.choice(NOUNS)
    label = f"{adjective} {noun}"
    adjective_slug = _slug(adjective)
    noun_slug = _slug(noun)
    suffix = digest[:10]
    profile_id = f"{adjective_slug}-{noun_slug}-{suffix}"
    package_prefix = package_root or rng.choice(PACKAGE_ROOTS)
    application_id = f"{package_prefix}.{adjective_slug}{noun_slug}.{_token(rng, 6)}{suffix[:6]}"

    if not ANDROID_APPLICATION_ID.match(application_id):
        raise ValueError(f"invalid generated applicationId: {application_id}")

    metadata = json.dumps(
        {
            "generator": "scripts/stealth/generate_android_identity.py",
            "profileId": profile_id,
            "seedFingerprint": digest[:16],
            "randomSeed": random_seed,
        },
        sort_keys=True,
        separators=(",", ":"),
    )

    return AndroidIdentity(
        application_id=application_id,
        app_label=label,
        launcher_label=label,
        identity_label=profile_id,
        identity_profile_id=profile_id,
        identity_metadata=metadata,
        vpn_session_name=f"{label} Session",
        notification_channel_vpn="Connection",
        notification_channel_data_usage="Usage",
        notification_title=label,
        notification_connected_text="Connection is active",
        notification_starting_text="Starting connection...",
        notification_disconnect_action="Disconnect",
        quick_tile_active_label="Connected",
        quick_tile_inactive_label="Disconnected",
        app_icon=app_icon,
        app_round_icon=app_round_icon,
        notification_small_icon=notification_small_icon,
        quick_tile_icon=quick_tile_icon,
        app_auth_scheme=f"{adjective_slug}{noun_slug}{suffix[:8]}",
    )


def write_properties(identity: AndroidIdentity, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Generated Android identity profile. Do not commit generated profiles.",
    ]
    for key, value in identity.as_properties().items():
        lines.append(f"{key}={_escape_properties(value)}")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _escape_properties(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a Stealth Android identity properties file."
    )
    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Path to write the generated .properties profile.",
    )
    parser.add_argument(
        "--seed",
        help="Optional deterministic seed. Omit to generate a fresh random identity.",
    )
    parser.add_argument(
        "--package-root",
        help="Optional first applicationId segment. Defaults to a neutral generated root.",
    )
    parser.add_argument("--app-icon", default="@drawable/neutral_app_icon")
    parser.add_argument("--app-round-icon", default="@drawable/neutral_app_icon")
    parser.add_argument(
        "--notification-small-icon", default="@drawable/neutral_notification_icon"
    )
    parser.add_argument("--quick-tile-icon", default="@drawable/neutral_notification_icon")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    identity = generate_identity(
        seed=args.seed,
        package_root=args.package_root,
        app_icon=args.app_icon,
        app_round_icon=args.app_round_icon,
        notification_small_icon=args.notification_small_icon,
        quick_tile_icon=args.quick_tile_icon,
    )
    write_properties(identity, args.output)
    print(f"Wrote Android identity profile: {args.output}")
    print(f"applicationId={identity.application_id}")
    print(f"appLabel={identity.app_label}")
    print(f"identityProfileId={identity.identity_profile_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
