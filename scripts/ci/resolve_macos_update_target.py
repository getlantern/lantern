#!/usr/bin/env python3
"""Resolve and validate the live macOS beta target for the update smoke test."""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
import json
import pathlib
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass

from defusedxml import ElementTree as ET
from defusedxml.common import DefusedXmlException


SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DEFAULT_APPCAST_URL = (
    "https://update.getlantern.org/update/lantern/appcast.xml?channel=beta"
)
USER_AGENT = "LanternAutoUpdateSmoke/1.0"
DISPLAY_VERSION_RE = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")


class TargetError(Exception):
    """Raised when the beta appcast cannot provide a safe update target."""


@dataclass(frozen=True)
class UpdateTarget:
    appcast_url: str
    appcast_sha256: str
    target_build: int
    fixture_build: int
    display_version: str
    dmg_url: str
    dmg_length: int
    ed_signature: str

    @property
    def fixture_pubspec_version(self) -> str:
        return f"{self.display_version}+{self.fixture_build}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise TargetError(message)


def fetch_appcast(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/rss+xml, application/xml;q=0.9",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            require(response.status == 200, f"appcast returned HTTP {response.status}")
            return response.read()
    except urllib.error.HTTPError as err:
        content_type = err.headers.get_content_type()
        body = err.read(256).decode("utf-8", errors="replace").strip()
        detail = f": {body}" if content_type == "text/plain" and body else ""
        raise TargetError(f"appcast returned HTTP {err.code}{detail}") from err
    except urllib.error.URLError as err:
        raise TargetError(f"unable to fetch appcast: {err.reason}") from err


def parse_target(xml_data: bytes, appcast_url: str) -> UpdateTarget:
    try:
        root = ET.fromstring(xml_data)
    except (DefusedXmlException, ET.ParseError) as err:
        raise TargetError(f"invalid or unsafe appcast XML: {err}") from err

    item = root.find("./channel/item")
    require(item is not None, "appcast has no release item")

    version_node = item.find(f"{{{SPARKLE_NS}}}version")
    version = (
        version_node.text.strip()
        if version_node is not None and version_node.text
        else ""
    )
    require(
        version.isascii() and version.isdigit(),
        f"appcast Sparkle version must be numeric; got {version!r}",
    )
    target_build = int(version)
    require(target_build > 1, "appcast Sparkle build must be greater than 1")

    short_version_node = item.find(f"{{{SPARKLE_NS}}}shortVersionString")
    display_version = (
        short_version_node.text.strip()
        if short_version_node is not None and short_version_node.text
        else ""
    )
    require(
        DISPLAY_VERSION_RE.fullmatch(display_version) is not None,
        "appcast display version must be a valid dotted version",
    )

    mac_enclosures = [
        enclosure
        for enclosure in item.findall("enclosure")
        if enclosure.attrib.get(f"{{{SPARKLE_NS}}}os") == "macos"
    ]
    require(mac_enclosures, "appcast has no macOS enclosure")
    require(len(mac_enclosures) == 1, "appcast has more than one macOS enclosure")
    enclosure = mac_enclosures[0]

    dmg_url = enclosure.attrib.get("url", "").strip()
    parsed_url = urllib.parse.urlparse(dmg_url)
    require(
        parsed_url.scheme == "https" and bool(parsed_url.netloc),
        "macOS update URL must use HTTPS",
    )
    require(
        parsed_url.path.lower().endswith(".dmg"),
        "macOS update URL must point to a DMG",
    )

    length_text = enclosure.attrib.get("length", "").strip()
    require(
        length_text.isascii() and length_text.isdigit(),
        "macOS enclosure length must be numeric",
    )
    dmg_length = int(length_text)
    require(dmg_length > 0, "macOS enclosure length must be positive")

    signature = enclosure.attrib.get(f"{{{SPARKLE_NS}}}edSignature", "").strip()
    require(bool(signature), "macOS enclosure is missing an EdDSA signature")
    try:
        decoded_signature = base64.b64decode(signature, validate=True)
    except (binascii.Error, ValueError) as err:
        raise TargetError("macOS EdDSA signature is not valid base64") from err
    require(len(decoded_signature) == 64, "macOS EdDSA signature must decode to 64 bytes")

    return UpdateTarget(
        appcast_url=appcast_url,
        appcast_sha256=hashlib.sha256(xml_data).hexdigest(),
        target_build=target_build,
        fixture_build=target_build - 1,
        display_version=display_version,
        dmg_url=dmg_url,
        dmg_length=dmg_length,
        ed_signature=signature,
    )


def write_fixture_pubspec(
    source: pathlib.Path,
    destination: pathlib.Path,
    target: UpdateTarget,
) -> None:
    original = source.read_text(encoding="utf-8")
    updated, count = re.subn(
        r"(?m)^version:\s*[^\r\n]+$",
        f"version: {target.fixture_pubspec_version}",
        original,
        count=1,
    )
    require(count == 1, f"could not replace version in {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(updated, encoding="utf-8")


def write_github_output(path: pathlib.Path, target: UpdateTarget) -> None:
    outputs = {
        "target_build": str(target.target_build),
        "fixture_build": str(target.fixture_build),
        "display_version": target.display_version,
        "fixture_version": target.fixture_pubspec_version,
    }
    with path.open("a", encoding="utf-8") as output:
        for name, value in outputs.items():
            output.write(f"{name}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--appcast-url", default=DEFAULT_APPCAST_URL)
    parser.add_argument("--appcast-output", required=True, type=pathlib.Path)
    parser.add_argument("--target-output", required=True, type=pathlib.Path)
    parser.add_argument("--pubspec-input", required=True, type=pathlib.Path)
    parser.add_argument("--pubspec-output", required=True, type=pathlib.Path)
    parser.add_argument("--github-output", type=pathlib.Path)
    args = parser.parse_args()

    try:
        xml_data = fetch_appcast(args.appcast_url)
        args.appcast_output.parent.mkdir(parents=True, exist_ok=True)
        args.appcast_output.write_bytes(xml_data)
        target = parse_target(xml_data, args.appcast_url)
        args.target_output.parent.mkdir(parents=True, exist_ok=True)
        args.target_output.write_text(
            json.dumps(asdict(target), indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        write_fixture_pubspec(args.pubspec_input, args.pubspec_output, target)
        if args.github_output is not None:
            write_github_output(args.github_output, target)
    except (OSError, TargetError) as err:
        raise SystemExit(f"unable to resolve macOS beta update target: {err}") from err

    print(
        "[E2E] resolved live beta "
        f"{target.display_version} build {target.target_build}; "
        f"fixture build is {target.fixture_build}"
    )


if __name__ == "__main__":
    main()
