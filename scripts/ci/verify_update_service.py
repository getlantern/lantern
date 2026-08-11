#!/usr/bin/env python3
"""Verify Lantern's public update service after a release."""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional

from defusedxml import ElementTree as ET
from defusedxml.common import DefusedXmlException


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
KNOWN_PLATFORMS = frozenset({"android", "ios", "linux", "macos", "windows"})
JSON_UPDATE_PLATFORMS = {
    "android": {"os": "android", "arch": "arm64", "suffix": ".apk"},
    "linux": {"os": "linux", "arch": "amd64", "suffix": ".deb"},
}
APPCAST_PLATFORMS = {
    "macos": ".dmg",
    "windows": ".exe",
}
VERIFIABLE_PLATFORMS = frozenset(
    set(JSON_UPDATE_PLATFORMS) | set(APPCAST_PLATFORMS)
)


@dataclass(frozen=True)
class Config:
    update_url: str
    channel: str
    version: str
    timeout_seconds: int
    interval_seconds: int
    platforms: frozenset[str]
    sparkle_version: str = ""


class VerificationError(Exception):
    pass


def normalize_version(version: str) -> str:
    return version[1:] if version[:1].lower() == "v" else version


def normalize_platforms(platform: str) -> frozenset[str]:
    normalized = platform.strip().lower()
    if normalized == "" or normalized == "all":
        return VERIFIABLE_PLATFORMS

    platforms = frozenset(
        part.strip().lower() for part in normalized.split(",") if part.strip()
    )
    unknown = platforms - KNOWN_PLATFORMS
    if unknown:
        raise VerificationError(
            f"unsupported release platform: {', '.join(sorted(unknown))}"
        )
    # iOS is a release platform, but not an update-service platform. Returning
    # an empty set lets iOS-only beta releases pass without probing dead paths.
    return platforms & VERIFIABLE_PLATFORMS


def request_update(update_url: str, app_version: str, tags: dict[str, str]) -> tuple[int, dict[str, Any]]:
    payload = {
        "version": 1,
        "app_version": app_version,
        "os_version": "13.0.0",
        "checksum": "",
        "tags": tags,
    }
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        update_url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            if not body:
                return response.status, {}
            return response.status, json.loads(body.decode("utf-8"))
    except urllib.error.HTTPError as err:
        body = err.read()
        if not body:
            return err.code, {}
        try:
            return err.code, json.loads(body.decode("utf-8"))
        except json.JSONDecodeError:
            return err.code, {"error": body.decode("utf-8", errors="replace")}


def request_text(url: str) -> tuple[int, str]:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode("utf-8", errors="replace")


def appcast_url(update_url: str, channel: str) -> str:
    return f"{update_url.rstrip('/')}/appcast.xml?channel={channel}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def verify_json_beta(update_url: str, expected_version: str, platform: str) -> None:
    update = JSON_UPDATE_PLATFORMS[platform]
    status, result = request_update(
        update_url,
        "0.0.0",
        {"os": update["os"], "arch": update["arch"], "channel": "beta"},
    )
    require(status == 200, f"beta {platform} update returned HTTP {status}: {result}")
    require(
        result.get("version") == expected_version,
        f"beta {platform} returned {result.get('version')}, want {expected_version}",
    )
    require(
        result.get("url", "").endswith(update["suffix"]),
        f"beta {platform} update URL does not end with {update['suffix']}: "
        f"{result.get('url')}",
    )
    require(result.get("checksum"), f"beta {platform} update is missing checksum")


def verify_stable_excludes_beta(update_url: str, beta_version: str, platform: str) -> None:
    update = JSON_UPDATE_PLATFORMS[platform]
    status, result = request_update(
        update_url,
        "0.0.0",
        {"os": update["os"], "arch": update["arch"], "channel": "stable"},
    )
    if status == 204:
        return
    require(status == 200, f"stable {platform} update returned HTTP {status}: {result}")
    require(
        result.get("version") != beta_version,
        f"stable {platform} returned beta version {beta_version}",
    )
    require(
        "beta" not in result.get("url", "").lower(),
        f"stable {platform} returned beta URL: {result.get('url')}",
    )


def parse_appcast(xml_text: str) -> tuple[str, list[dict[str, str]]]:
    try:
        root = ET.fromstring(xml_text)
    except DefusedXmlException as err:
        raise VerificationError(f"unsafe appcast XML: {err}") from err
    item = root.find("./channel/item")
    require(item is not None, "appcast has no release item")
    version_node = item.find(f"{{{SPARKLE_NS}}}version")
    require(version_node is not None and version_node.text, "appcast item has no Sparkle version")

    enclosures = []
    for enclosure in item.findall("enclosure"):
        enclosures.append(
            {
                "url": enclosure.attrib.get("url", ""),
                "ed_signature": enclosure.attrib.get(f"{{{SPARKLE_NS}}}edSignature", ""),
                "dsa_signature": enclosure.attrib.get(f"{{{SPARKLE_NS}}}dsaSignature", ""),
                "os": enclosure.attrib.get(f"{{{SPARKLE_NS}}}os", ""),
            }
        )
    require(enclosures, "appcast item has no enclosures")
    return version_node.text, enclosures


def verify_beta_appcast(
    update_url: str,
    beta_version: str,
    platforms: frozenset[str],
) -> None:
    # The appcast is channel-wide, so partial desktop releases should only
    # require the enclosures they actually published.
    required_platforms = {
        os_name: suffix
        for os_name, suffix in APPCAST_PLATFORMS.items()
        if os_name in platforms
    }
    if not required_platforms:
        return

    status, xml_text = request_text(appcast_url(update_url, "beta"))
    require(status == 200, f"beta appcast returned HTTP {status}: {xml_text}")
    version, enclosures = parse_appcast(xml_text)
    require(version == beta_version, f"beta appcast version is {version}, want {beta_version}")

    by_os = {enclosure["os"]: enclosure for enclosure in enclosures}
    for os_name, suffix in required_platforms.items():
        enclosure = by_os.get(os_name)
        require(enclosure is not None, f"beta appcast missing {os_name} enclosure")
        signature_key = "ed_signature" if os_name == "macos" else "dsa_signature"
        require(
            enclosure[signature_key],
            f"beta appcast {os_name} enclosure missing {signature_key}",
        )
        require(
            enclosure["url"].endswith(suffix),
            f"beta appcast {os_name} URL does not end with {suffix}: {enclosure['url']}",
        )


def verify_stable_appcast_excludes_beta(update_url: str, beta_version: str) -> None:
    status, xml_text = request_text(appcast_url(update_url, "stable"))
    if status == 404:
        print("stable appcast is not available yet; beta is not leaking into it")
        return
    require(status == 200, f"stable appcast returned HTTP {status}: {xml_text}")
    require(beta_version not in xml_text, f"stable appcast contains beta version {beta_version}")
    version, enclosures = parse_appcast(xml_text)
    require(version != beta_version, f"stable appcast item is beta version {beta_version}")
    require(enclosures, "stable appcast has no enclosures")


def run_checks_once(config: Config) -> None:
    expected_version = normalize_version(config.version)
    if config.channel != "beta":
        raise VerificationError(f"unsupported verification channel: {config.channel}")
    if not config.platforms:
        print("no updater-backed artifacts for this release platform; skipping update verification")
        return

    for platform in sorted(config.platforms & set(JSON_UPDATE_PLATFORMS)):
        verify_json_beta(config.update_url, expected_version, platform)
        verify_stable_excludes_beta(config.update_url, expected_version, platform)

    if config.platforms & set(APPCAST_PLATFORMS):
        expected_sparkle_version = normalize_version(
            config.sparkle_version or config.version
        )
        verify_beta_appcast(
            config.update_url,
            expected_sparkle_version,
            config.platforms,
        )
        verify_stable_appcast_excludes_beta(
            config.update_url,
            expected_sparkle_version,
        )


def poll_until_verified(config: Config) -> None:
    deadline = time.monotonic() + config.timeout_seconds
    attempt = 0
    last_error: Optional[Exception] = None

    while time.monotonic() <= deadline:
        attempt += 1
        try:
            run_checks_once(config)
            print(f"update service verification passed on attempt {attempt}")
            return
        except Exception as err:  # noqa: BLE001
            last_error = err
            remaining = int(deadline - time.monotonic())
            if remaining <= 0:
                break
            print(f"attempt {attempt} failed: {err}")
            print(f"retrying in {config.interval_seconds}s ({remaining}s remaining)")
            time.sleep(config.interval_seconds)

    raise SystemExit(f"update service verification failed: {last_error}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update-url", default="https://update.getlantern.org/update/lantern")
    parser.add_argument("--channel", default="beta")
    parser.add_argument(
        "--platform",
        default="all",
        help="'all' or comma-separated release platforms",
    )
    parser.add_argument("--version", required=True, help="Release version, with or without leading v")
    parser.add_argument("--sparkle-version", default="", help="Desktop bundle build number")
    parser.add_argument("--timeout-seconds", type=int, default=2700)
    parser.add_argument("--interval-seconds", type=int, default=60)
    args = parser.parse_args()

    poll_until_verified(
        Config(
            update_url=args.update_url,
            channel=args.channel,
            version=args.version,
            timeout_seconds=args.timeout_seconds,
            interval_seconds=args.interval_seconds,
            platforms=normalize_platforms(args.platform),
            sparkle_version=args.sparkle_version,
        )
    )


if __name__ == "__main__":
    main()
