#!/usr/bin/env python3
"""Verify that a Lantern release, its tag, and public aliases agree."""

from __future__ import annotations

import argparse
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Mapping


KNOWN_PLATFORMS = frozenset({"android", "ios", "linux", "macos", "windows"})
LINUX_ARCHES = frozenset({"all", "amd64", "arm64"})


class VerificationError(Exception):
    pass


@dataclass(frozen=True)
class Config:
    repository: str
    release_tag: str
    version: str
    storage_version: str
    build_type: str
    platforms: frozenset[str]
    linux_arch: str
    bucket: str
    expected_commit: str
    github_api_url: str = "https://api.github.com"
    s3_url: str = "https://s3.amazonaws.com"
    expect_draft: bool = True
    github_token: str = ""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def normalize_platforms(value: str) -> frozenset[str]:
    normalized = value.strip().lower()
    if normalized == "all":
        return KNOWN_PLATFORMS

    platforms = frozenset(
        part.strip() for part in normalized.split(",") if part.strip()
    )
    require(bool(platforms), "at least one release platform is required")
    unknown = platforms - KNOWN_PLATFORMS
    require(
        not unknown,
        f"unsupported release platform: {', '.join(sorted(unknown))}",
    )
    return platforms


def required_asset_names(
    build_type: str,
    platforms: frozenset[str],
    linux_arch: str,
) -> frozenset[str]:
    require(build_type in {"production", "beta"}, f"unsupported build type: {build_type}")
    require(linux_arch in LINUX_ARCHES, f"unsupported Linux architecture: {linux_arch}")

    base_name = "lantern-installer"
    if build_type == "beta":
        base_name += "-beta"

    assets: set[str] = set()
    platform_extensions = {
        "android": "apk",
        "ios": "ipa",
        "macos": "dmg",
        "windows": "exe",
    }
    for platform, extension in platform_extensions.items():
        if platform in platforms:
            assets.add(f"{base_name}.{extension}")

    if "linux" in platforms:
        arches = ("amd64", "arm64") if linux_arch == "all" else (linux_arch,)
        for arch in arches:
            suffix = "-arm64" if arch == "arm64" else ""
            assets.update(
                f"{base_name}{suffix}.{extension}"
                for extension in ("deb", "rpm", "pkg.tar.zst")
            )

    return frozenset(assets)


def request_json(url: str, token: str = "") -> Any:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "lantern-release-verifier",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as err:
        body = err.read().decode("utf-8", errors="replace")
        raise VerificationError(f"GET {url} returned HTTP {err.code}: {body}") from err


def request_headers(url: str) -> Mapping[str, str]:
    request = urllib.request.Request(
        url,
        method="HEAD",
        headers={"User-Agent": "lantern-release-verifier"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            require(response.status == 200, f"HEAD {url} returned HTTP {response.status}")
            return {key.lower(): value for key, value in response.headers.items()}
    except urllib.error.HTTPError as err:
        raise VerificationError(f"HEAD {url} returned HTTP {err.code}") from err


def find_release(config: Config) -> dict[str, Any]:
    # The tag endpoint only returns published releases; the listing includes drafts.
    url = f"{config.github_api_url.rstrip('/')}/repos/{config.repository}/releases"
    page = 1
    while True:
        releases = request_json(f"{url}?per_page=100&page={page}", config.github_token)
        for release in releases:
            if release.get("tag_name") == config.release_tag:
                return release
        if len(releases) < 100:
            raise VerificationError(f"GitHub release {config.release_tag} not found")
        page += 1


def validate_release(
    release: Mapping[str, Any],
    config: Config,
    required_assets: frozenset[str],
) -> dict[str, Mapping[str, Any]]:
    require(release.get("tag_name") == config.release_tag, "GitHub release tag does not match")
    require(
        release.get("draft") is config.expect_draft,
        f"GitHub release draft={release.get('draft')}, want {config.expect_draft}",
    )

    expected_prerelease = config.build_type == "beta"
    require(
        release.get("prerelease") is expected_prerelease,
        f"GitHub release prerelease={release.get('prerelease')}, want {expected_prerelease}",
    )

    expected_title = (
        f"Beta {config.version}"
        if config.build_type == "beta"
        else f"Lantern {config.version}"
    )
    require(
        release.get("name") == expected_title,
        f"GitHub release title is {release.get('name')!r}, want {expected_title!r}",
    )

    release_assets = {asset.get("name"): asset for asset in release.get("assets", [])}
    missing = required_assets - release_assets.keys()
    require(
        not missing,
        f"GitHub release is missing assets: {', '.join(sorted(missing))}",
    )
    empty = sorted(
        name
        for name in required_assets
        if int(release_assets[name].get("size", 0)) <= 0
        or release_assets[name].get("state") != "uploaded"
    )
    require(not empty, f"GitHub release has incomplete assets: {', '.join(empty)}")
    return release_assets


def resolve_tag_commit(config: Config) -> str:
    encoded_tag = urllib.parse.quote(config.release_tag, safe="")
    ref = request_json(
        f"{config.github_api_url.rstrip('/')}/repos/{config.repository}/git/ref/tags/{encoded_tag}",
        config.github_token,
    )
    target = ref.get("object", {})

    for _ in range(5):
        object_type = target.get("type")
        sha = target.get("sha")
        require(bool(sha), f"Git tag {config.release_tag} has no target SHA")
        if object_type == "commit":
            return str(sha)
        require(object_type == "tag", f"Git tag points to unsupported object type: {object_type}")
        tag = request_json(
            f"{config.github_api_url.rstrip('/')}/repos/{config.repository}/git/tags/{sha}",
            config.github_token,
        )
        target = tag.get("object", {})

    raise VerificationError(f"Git tag {config.release_tag} has too many annotation levels")


def validate_assets(
    config: Config,
    required_assets: frozenset[str],
    release_assets: Mapping[str, Mapping[str, Any]],
) -> None:
    base_url = (
        f"{config.s3_url.rstrip('/')}/{config.bucket}/releases/{config.build_type}"
    )
    for asset in sorted(required_assets):
        versioned_url = f"{base_url}/{config.storage_version}/{asset}"
        versioned = request_headers(versioned_url)

        versioned_size = int(versioned.get("content-length", "0"))
        require(versioned_size > 0, f"versioned object is empty: {versioned_url}")
        require(
            versioned_size == int(release_assets[asset].get("size", 0)),
            f"S3 and GitHub release sizes differ for {asset}",
        )

        versioned_sha256 = versioned.get("x-amz-meta-sha256", "")
        github_digest = release_assets[asset].get("digest", "")
        require(
            bool(re.fullmatch(r"[0-9a-f]{64}", versioned_sha256)),
            f"versioned object has no SHA-256 metadata: {versioned_url}",
        )
        require(
            github_digest == f"sha256:{versioned_sha256}",
            f"S3 and GitHub release SHA-256 digests differ for {asset}",
        )
        # Drafts are checked before promotion; public releases must match aliases too.
        if not config.expect_draft:
            latest = request_headers(f"{base_url}/latest/{asset}")
            require(
                int(latest.get("content-length", "0")) == versioned_size,
                f"latest alias size differs for {asset}",
            )
            # Multipart copies can have different ETags for identical content.
            require(
                latest.get("x-amz-meta-sha256", "") == versioned_sha256,
                f"latest alias SHA-256 differs for {asset}",
            )


def verify(config: Config) -> None:
    required_assets = required_asset_names(
        config.build_type,
        config.platforms,
        config.linux_arch,
    )
    require(bool(required_assets), "release has no required downloadable assets")

    release = find_release(config)
    release_assets = validate_release(release, config, required_assets)

    tag_commit = resolve_tag_commit(config)
    require(
        tag_commit == config.expected_commit,
        f"release tag points to {tag_commit}, want {config.expected_commit}",
    )
    validate_assets(config, required_assets, release_assets)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True, help="GitHub repository in owner/name form")
    parser.add_argument("--release-tag", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--storage-version", required=True)
    parser.add_argument("--build-type", choices=("production", "beta"), required=True)
    parser.add_argument("--platform", default="all")
    parser.add_argument("--linux-arch", choices=sorted(LINUX_ARCHES), default="all")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--github-api-url", default="https://api.github.com")
    parser.add_argument("--s3-url", default="https://s3.amazonaws.com")
    parser.add_argument("--expect-draft", action=argparse.BooleanOptionalAction, default=True)
    args = parser.parse_args()

    verify(
        Config(
            repository=args.repository,
            release_tag=args.release_tag,
            version=args.version,
            storage_version=args.storage_version,
            build_type=args.build_type,
            platforms=normalize_platforms(args.platform),
            linux_arch=args.linux_arch,
            bucket=args.bucket,
            expected_commit=args.expected_commit,
            github_api_url=args.github_api_url,
            s3_url=args.s3_url,
            expect_draft=args.expect_draft,
            github_token=os.environ.get("GH_TOKEN", ""),
        )
    )
    print("Release alignment checks passed")


if __name__ == "__main__":
    main()
