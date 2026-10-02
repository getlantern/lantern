#!/usr/bin/env python3
"""Verify Lantern's public update service after a release."""

from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Optional

from defusedxml import ElementTree as ET
from defusedxml.common import DefusedXmlException


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
USER_AGENT = "LanternUpdateVerifier/1.0"
# Retrying is only useful while a release propagates, which surfaces as 204/404
# or a stale version. These statuses mean the request itself is unacceptable, so
# polling for 45 minutes cannot change the outcome.
PERMANENT_STATUS_HINTS = {
    400: "malformed request payload",
    403: "blocked before reaching the update service; check the User-Agent",
    417: "payload rejected; non-Android requests must send a checksum",
}
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
    asset_base_url: str = ""
    linux_arch: str = "all"


class VerificationError(Exception):
    pass


class PermanentVerificationError(VerificationError):
    """A failure that retrying cannot clear."""


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


def reject_permanent(status: int, url: str, detail: Any) -> None:
    hint = PERMANENT_STATUS_HINTS.get(status)
    if hint is None:
        return
    raise PermanentVerificationError(f"{url} returned HTTP {status} ({hint}): {detail}")


def request_update(update_url: str, app_version: str, tags: dict[str, str]) -> tuple[int, dict[str, Any]]:
    payload = {
        "version": 1,
        "app_version": app_version,
        "os_version": "13.0.0",
        # Non-Android clients require a checksum; an unknown binary gets a full download.
        "checksum": "" if tags.get("os") == "android" else "0" * 64,
        "tags": tags,
    }
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        update_url,
        data=data,
        headers={"Content-Type": "application/json", "User-Agent": USER_AGENT},
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
            result: dict[str, Any] = {}
        else:
            try:
                result = json.loads(body.decode("utf-8"))
            except json.JSONDecodeError:
                result = {"error": body.decode("utf-8", errors="replace")}
        reject_permanent(err.code, update_url, result)
        return err.code, result


def request_text(url: str) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        reject_permanent(err.code, url, body)
        return err.code, body


def appcast_url(update_url: str, channel: str) -> str:
    return f"{update_url.rstrip('/')}/appcast.xml?channel={channel}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def verify_json_channel(
    update_url: str,
    expected_version: str,
    platform: str,
    channel: str,
    expected_url: str = "",
    arch: str = "",
) -> None:
    update = JSON_UPDATE_PLATFORMS[platform]
    status, result = request_update(
        update_url,
        "0.0.0",
        {"os": update["os"], "arch": arch or update["arch"], "channel": channel},
    )
    require(status == 200, f"{channel} {platform} update returned HTTP {status}: {result}")
    require(
        result.get("version") == expected_version,
        f"{channel} {platform} returned {result.get('version')}, want {expected_version}",
    )
    require(
        result.get("url", "").endswith(update["suffix"]),
        f"{channel} {platform} update URL does not end with {update['suffix']}: "
        f"{result.get('url')}",
    )
    if expected_url:
        require(
            result.get("url") == expected_url,
            f"{channel} {platform} returned URL {result.get('url')}, want {expected_url}",
        )
    require(result.get("checksum"), f"{channel} {platform} update is missing checksum")


def verify_stable_excludes_beta(
    update_url: str, beta_version: str, platform: str, arch: str = ""
) -> None:
    update = JSON_UPDATE_PLATFORMS[platform]
    status, result = request_update(
        update_url,
        "0.0.0",
        {"os": update["os"], "arch": arch or update["arch"], "channel": "stable"},
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
                "os": enclosure.attrib.get(f"{{{SPARKLE_NS}}}os", ""),
            }
        )
    require(enclosures, "appcast item has no enclosures")
    return version_node.text, enclosures


def appcast_download_urls(update_url: str, asset_url: str) -> set[str]:
    """Accept the release object at its origin or through the update server."""
    urls = {asset_url}
    asset = urllib.parse.urlsplit(asset_url)
    if (
        asset.scheme == "https"
        and asset.netloc in {"s3.amazonaws.com", "s3.us-east-1.amazonaws.com"}
        and asset.path.startswith("/lantern.io/releases/")
        and not (asset.query or asset.fragment or "%" in asset.path)
    ):
        endpoint = urllib.parse.urlsplit(update_url)
        urls.add(urllib.parse.urlunsplit((
            endpoint.scheme, endpoint.netloc, asset.path.removeprefix("/lantern.io"), "", "",
        )))
    return urls


def verify_appcast_channel(
    update_url: str,
    expected_version: str,
    platforms: frozenset[str],
    channel: str,
    expected_base_url: str = "",
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

    status, xml_text = request_text(appcast_url(update_url, channel))
    require(status == 200, f"{channel} appcast returned HTTP {status}: {xml_text}")
    version, enclosures = parse_appcast(xml_text)
    require(
        version == expected_version,
        f"{channel} appcast version is {version}, want {expected_version}",
    )

    by_os = {enclosure["os"]: enclosure for enclosure in enclosures}
    for os_name, suffix in required_platforms.items():
        enclosure = by_os.get(os_name)
        require(enclosure is not None, f"{channel} appcast missing {os_name} enclosure")
        require(
            enclosure["ed_signature"],
            f"{channel} appcast {os_name} enclosure missing EdDSA signature",
        )
        require(
            enclosure["url"].endswith(suffix),
            f"{channel} appcast {os_name} URL does not end with {suffix}: "
            f"{enclosure['url']}",
        )
        if expected_base_url:
            channel_suffix = "-beta" if channel == "beta" else ""
            expected_url = (
                f"{expected_base_url.rstrip('/')}/"
                f"lantern-installer{channel_suffix}{suffix}"
            )
            # The feed may serve the same installer through its /releases/ route.
            expected_urls = appcast_download_urls(update_url, expected_url)
            require(
                enclosure["url"] in expected_urls,
                f"{channel} appcast {os_name} returned URL {enclosure['url']}, "
                f"want one of {sorted(expected_urls)}",
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
    if config.channel not in {"beta", "stable"}:
        raise VerificationError(f"unsupported verification channel: {config.channel}")
    require(config.linux_arch in {"all", "amd64", "arm64"}, "unsupported Linux architecture")
    if not config.platforms:
        print("no updater-backed artifacts for this release platform; skipping update verification")
        return

    for platform in sorted(config.platforms & set(JSON_UPDATE_PLATFORMS)):
        update = JSON_UPDATE_PLATFORMS[platform]
        channel_suffix = "-beta" if config.channel == "beta" else ""
        arches = [update["arch"]]
        if platform == "linux":
            arches = ["amd64", "arm64"] if config.linux_arch == "all" else [config.linux_arch]
        for arch in arches:
            expected_url = ""
            if config.asset_base_url:
                arch_suffix = "-arm64" if platform == "linux" and arch == "arm64" else ""
                expected_url = (
                    f"{config.asset_base_url.rstrip('/')}/"
                    f"lantern-installer{channel_suffix}{arch_suffix}{update['suffix']}"
                )
            verify_json_channel(
                config.update_url, expected_version, platform, config.channel, expected_url, arch,
            )
            if config.channel == "beta":
                verify_stable_excludes_beta(config.update_url, expected_version, platform, arch)

    if config.platforms & set(APPCAST_PLATFORMS):
        require(
            bool(config.sparkle_version.strip()),
            "--sparkle-version is required when verifying macOS or Windows appcasts",
        )
        expected_sparkle_version = normalize_version(config.sparkle_version)
        verify_appcast_channel(
            config.update_url,
            expected_sparkle_version,
            config.platforms,
            config.channel,
            config.asset_base_url,
        )
        if config.channel == "beta":
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
        except PermanentVerificationError as err:
            raise SystemExit(
                f"update service verification failed on attempt {attempt}, "
                f"not retrying: {err}"
            )
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
    parser.add_argument("--channel", choices=("stable", "beta"), default="beta")
    parser.add_argument(
        "--platform",
        default="all",
        help="'all' or comma-separated release platforms",
    )
    parser.add_argument("--version", required=True, help="Release version, with or without leading v")
    parser.add_argument("--sparkle-version", default="", help="Desktop bundle build number")
    parser.add_argument("--linux-arch", choices=("all", "amd64", "arm64"), default="all")
    parser.add_argument(
        "--asset-base-url",
        default="",
        help="Expected public directory for the promoted release assets",
    )
    parser.add_argument("--timeout-seconds", type=int, default=2700)
    parser.add_argument("--interval-seconds", type=int, default=60)
    args = parser.parse_args()

    platforms = normalize_platforms(args.platform)
    if platforms & set(APPCAST_PLATFORMS) and not args.sparkle_version.strip():
        parser.error(
            "--sparkle-version is required when verifying macOS or Windows appcasts"
        )

    poll_until_verified(
        Config(
            update_url=args.update_url,
            channel=args.channel,
            version=args.version,
            timeout_seconds=args.timeout_seconds,
            interval_seconds=args.interval_seconds,
            platforms=platforms,
            sparkle_version=args.sparkle_version,
            asset_base_url=args.asset_base_url,
            linux_arch=args.linux_arch,
        )
    )


if __name__ == "__main__":
    main()
