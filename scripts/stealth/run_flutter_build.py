#!/usr/bin/env python3
"""Run a Flutter build with a sanitized Stealth package graph and assets."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Iterable


BACKUP_PATHS = (
    Path("pubspec.yaml"),
    Path("pubspec.lock"),
    Path(".flutter-plugins"),
    Path(".flutter-plugins-dependencies"),
    Path(".dart_tool/package_config.json"),
    Path(".dart_tool/package_graph.json"),
    Path("linux/flutter/generated_plugin_registrant.cc"),
    Path("linux/flutter/generated_plugin_registrant.h"),
    Path("linux/flutter/generated_plugins.cmake"),
    Path("macos/Flutter/GeneratedPluginRegistrant.swift"),
    Path("windows/flutter/generated_plugin_registrant.cc"),
    Path("windows/flutter/generated_plugin_registrant.h"),
    Path("windows/flutter/generated_plugins.cmake"),
)

SVG_ASSETS = {
    "connected.svg": "#2e7d32",
    "connecting.svg": "#1565c0",
    "disconnected.svg": "#757575",
}


class StealthBuildError(RuntimeError):
    pass


def load_profile(path: Path | None) -> dict[str, object]:
    if path is None:
        return {}
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except OSError as exc:
        raise StealthBuildError(f"failed to read stealth profile {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise StealthBuildError(f"invalid stealth profile JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise StealthBuildError(f"stealth profile must be a JSON object: {path}")
    return value


def read_version(pubspec: Path) -> str:
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            version = line.split(":", 1)[1].strip()
            if version:
                return version
    raise StealthBuildError("pubspec.yaml is missing a version line")


def write_svg(path: Path, color: str) -> None:
    path.write_text(
        f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <circle cx="24" cy="24" r="20" fill="{color}"/>
  <circle cx="24" cy="24" r="8" fill="#ffffff" opacity="0.92"/>
</svg>
""",
        encoding="utf-8",
    )


def generate_assets(root: Path, profile: dict[str, object]) -> None:
    asset_root = root / "build/mobile/flutter_assets"
    images = asset_root / "images"
    locales = asset_root / "locales"
    if asset_root.exists():
        shutil.rmtree(asset_root)
    images.mkdir(parents=True, exist_ok=True)
    locales.mkdir(parents=True, exist_ok=True)

    for name, color in SVG_ASSETS.items():
        write_svg(images / name, color)

    app_name = str(profile.get("appName") or "Mobile App")
    for source in sorted((root / "assets/locales").glob("*.po")):
        locale_name = source.stem
        (locales / source.name).write_text(
            "\n".join(
                [
                    'msgid ""',
                    'msgstr ""',
                    f'"Language: {locale_name}\\n"',
                    '"Content-Type: text/plain; charset=UTF-8\\n"',
                    "",
                    'msgid "app_name"',
                    f'msgstr "{po_escape(app_name)}"',
                    "",
                    'msgid "connect"',
                    'msgstr "Connect"',
                    "",
                    'msgid "disconnect"',
                    'msgstr "Disconnect"',
                    "",
                    'msgid "connected"',
                    'msgstr "Connected"',
                    "",
                    'msgid "connecting"',
                    'msgstr "Connecting"',
                    "",
                    'msgid "disconnected"',
                    'msgstr "Disconnected"',
                    "",
                    'msgid "manual_proxy_host"',
                    'msgstr "Host"',
                    "",
                    'msgid "manual_proxy_port"',
                    'msgstr "Port"',
                    "",
                ]
            ),
            encoding="utf-8",
        )


def po_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def sanitized_pubspec(version: str) -> str:
    return f"""name: mobile_client
description: Mobile app
publish_to: "none"
version: {version}

environment:
  sdk: ^3.11.0
  flutter: ">=3.41.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  uses-material-design: true
  assets:
    - build/mobile/flutter_assets/images/
    - build/mobile/flutter_assets/locales/
"""


def backup_files(root: Path, backup_root: Path) -> set[Path]:
    existing: set[Path] = set()
    for relative in BACKUP_PATHS:
        source = root / relative
        target = backup_root / relative
        if not source.exists():
            continue
        existing.add(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    return existing


def restore_files(root: Path, backup_root: Path, existing: set[Path]) -> None:
    for relative in BACKUP_PATHS:
        source = backup_root / relative
        target = root / relative
        if relative in existing:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        elif target.exists():
            target.unlink()


def run(cmd: list[str], root: Path) -> int:
    print("Running sanitized Flutter build:", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=root).returncode


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(list(argv))
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("missing command after --")
    return args


def main(argv: Iterable[str]) -> int:
    args = parse_args(argv)
    root = Path.cwd()
    profile = load_profile(args.profile)
    backup_root = root / "build/mobile/flutter-backup"
    if backup_root.exists():
        shutil.rmtree(backup_root)
    backup_root.mkdir(parents=True, exist_ok=True)

    existing = backup_files(root, backup_root)
    try:
        generate_assets(root, profile)
        version = read_version(root / "pubspec.yaml")
        (root / "pubspec.yaml").write_text(sanitized_pubspec(version), encoding="utf-8")
        for stale in (
            root / "pubspec.lock",
            root / ".flutter-plugins",
            root / ".flutter-plugins-dependencies",
            root / ".dart_tool/package_config.json",
            root / ".dart_tool/package_graph.json",
        ):
            if stale.exists():
                stale.unlink()
        return run(args.command, root)
    finally:
        restore_files(root, backup_root, existing)
        shutil.rmtree(backup_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
