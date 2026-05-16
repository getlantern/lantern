#!/usr/bin/env python3
"""Scan built stealth artifacts for forbidden Lantern identifiers.

The scanner works on APK/AAB/ZIP-like archives and unpacked build output
directories. It only uses the Python standard library so it can run in CI before
tool-specific Android inspection utilities are installed.
"""

from __future__ import annotations

import argparse
import dataclasses
import fnmatch
import glob
import io
import json
import os
from pathlib import Path
import shlex
import sys
from typing import Any
import zipfile


ARCHIVE_SUFFIXES = {".apk", ".aab", ".zip", ".jar", ".aar", ".ap_"}
DEFAULT_CONFIG = Path(__file__).with_name("forbidden_tokens.json")
TEXT_ENCODINGS = ("utf-8", "utf-16le", "utf-16be")
ALLOWLIST_MATCH_FIELDS = frozenset(("token", "category", "location", "path", "encoding"))


class ConfigError(Exception):
    pass


@dataclasses.dataclass(frozen=True)
class Needle:
    encoding: str
    value: bytes


@dataclasses.dataclass(frozen=True)
class Rule:
    category: str
    token: str
    description: str
    case_sensitive: bool
    needles: tuple[Needle, ...]


@dataclasses.dataclass(frozen=True)
class Finding:
    location: str
    category: str
    token: str
    description: str
    encoding: str
    count: int
    first_offset: int
    excerpt: str


@dataclasses.dataclass
class ScanResult:
    targets: list[str]
    missing: list[str]
    scanned_blobs: int
    findings: list[Finding]
    errors: list[str]


def load_config(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as infile:
            config = json.load(infile)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"{path}: invalid JSON: {exc}") from exc
    except OSError as exc:
        raise ConfigError(f"{path}: unable to read config: {exc}") from exc

    if not isinstance(config, dict):
        raise ConfigError(f"{path}: config must be a JSON object")
    if not isinstance(config.get("categories"), dict):
        raise ConfigError(f"{path}: missing object field 'categories'")
    if not isinstance(config.get("modes"), dict):
        raise ConfigError(f"{path}: missing object field 'modes'")
    return config


def resolve_mode(config: dict[str, Any], mode: str) -> tuple[list[str], list[dict[str, Any]]]:
    modes = config["modes"]
    if mode not in modes:
        valid = ", ".join(sorted(modes))
        raise ConfigError(f"unknown mode '{mode}'. Valid modes: {valid}")

    categories: list[str] = []
    allowlist: list[dict[str, Any]] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        if name in visiting:
            raise ConfigError(f"mode inheritance cycle involving '{name}'")
        spec = modes.get(name)
        if not isinstance(spec, dict):
            raise ConfigError(f"mode '{name}' must be an object")

        visiting.add(name)
        parents = spec.get("extends", [])
        if isinstance(parents, str):
            parents = [parents]
        if not isinstance(parents, list):
            raise ConfigError(f"mode '{name}' field 'extends' must be a string or array")
        for parent in parents:
            if not isinstance(parent, str):
                raise ConfigError(f"mode '{name}' has non-string parent")
            if parent not in modes:
                raise ConfigError(f"mode '{name}' extends unknown mode '{parent}'")
            visit(parent)

        mode_categories = spec.get("categories", [])
        if not isinstance(mode_categories, list):
            raise ConfigError(f"mode '{name}' field 'categories' must be an array")
        for category in mode_categories:
            if not isinstance(category, str):
                raise ConfigError(f"mode '{name}' has non-string category")
            if category not in config["categories"]:
                raise ConfigError(f"mode '{name}' references unknown category '{category}'")
            if category not in categories:
                categories.append(category)

        mode_allowlist = spec.get("allowlist", [])
        if not isinstance(mode_allowlist, list):
            raise ConfigError(f"mode '{name}' field 'allowlist' must be an array")
        for item in mode_allowlist:
            if not isinstance(item, dict):
                raise ConfigError(f"mode '{name}' allowlist entries must be objects")
            validate_allowlist_entry(item, f"mode '{name}' allowlist")
            allowlist.append(item)

        visiting.remove(name)
        visited.add(name)

    global_allowlist = config.get("allowlist", [])
    if not isinstance(global_allowlist, list):
        raise ConfigError("top-level 'allowlist' must be an array when present")
    for item in global_allowlist:
        if not isinstance(item, dict):
            raise ConfigError("top-level allowlist entries must be objects")
        validate_allowlist_entry(item, "top-level allowlist")
        allowlist.append(item)

    visit(mode)
    return categories, allowlist


def validate_allowlist_entry(item: dict[str, Any], context: str) -> None:
    if not any(item.get(field) is not None for field in ALLOWLIST_MATCH_FIELDS):
        raise ConfigError(
            f"{context} entries must include at least one matcher field: "
            f"{', '.join(sorted(ALLOWLIST_MATCH_FIELDS))}"
        )


def compile_rules(config: dict[str, Any], categories: list[str]) -> list[Rule]:
    rules: list[Rule] = []
    for category in categories:
        category_spec = config["categories"][category]
        if not isinstance(category_spec, dict):
            raise ConfigError(f"category '{category}' must be an object")
        tokens = category_spec.get("tokens", [])
        if not isinstance(tokens, list):
            raise ConfigError(f"category '{category}' field 'tokens' must be an array")
        default_case = bool(category_spec.get("case_sensitive", False))
        category_description = str(category_spec.get("description", ""))

        for token_spec in tokens:
            if isinstance(token_spec, str):
                token = token_spec
                description = category_description
                case_sensitive = default_case
            elif isinstance(token_spec, dict):
                token = token_spec.get("token")
                description = str(token_spec.get("description", category_description))
                case_sensitive = bool(token_spec.get("case_sensitive", default_case))
            else:
                raise ConfigError(f"category '{category}' contains a non-string token")

            if not isinstance(token, str) or token == "":
                raise ConfigError(f"category '{category}' contains an empty token")
            rules.append(
                Rule(
                    category=category,
                    token=token,
                    description=description,
                    case_sensitive=case_sensitive,
                    needles=build_needles(token, case_sensitive),
                )
            )
    return rules


def build_needles(token: str, case_sensitive: bool) -> tuple[Needle, ...]:
    needles: list[Needle] = []
    for encoding in TEXT_ENCODINGS:
        value = token.encode(encoding)
        if not case_sensitive:
            value = value.lower()
        needles.append(Needle(encoding=encoding, value=value))
    return tuple(needles)


def pattern_matches(value: str, patterns: Any) -> bool:
    if patterns is None:
        return True
    if isinstance(patterns, str):
        patterns = [patterns]
    if not isinstance(patterns, list):
        return False
    return any(isinstance(pattern, str) and fnmatch.fnmatchcase(value, pattern) for pattern in patterns)


def finding_is_allowed(finding: Finding, allowlist: list[dict[str, Any]]) -> bool:
    for item in allowlist:
        token = item.get("token")
        if token is not None:
            if isinstance(token, str):
                tokens = [token]
            elif isinstance(token, list):
                tokens = token
            else:
                continue
            lowered = {str(candidate).lower() for candidate in tokens}
            if finding.token.lower() not in lowered:
                continue

        category = item.get("category")
        if category is not None:
            if isinstance(category, str):
                categories = [category]
            elif isinstance(category, list):
                categories = category
            else:
                continue
            if finding.category not in {str(candidate) for candidate in categories}:
                continue

        location = item.get("location", item.get("path"))
        if not pattern_matches(finding.location, location):
            continue

        encoding = item.get("encoding")
        if encoding is not None:
            if isinstance(encoding, str):
                encodings = [encoding]
            elif isinstance(encoding, list):
                encodings = encoding
            else:
                continue
            if finding.encoding not in {str(candidate) for candidate in encodings}:
                continue

        return True
    return False


def printable_excerpt(data: bytes, offset: int, width: int = 96) -> str:
    start = max(0, offset - width // 2)
    end = min(len(data), offset + width // 2)
    excerpt = data[start:end]
    rendered = "".join(chr(byte) if 32 <= byte < 127 else "." for byte in excerpt)
    if start > 0:
        rendered = "..." + rendered
    if end < len(data):
        rendered = rendered + "..."
    return rendered


def count_matches(haystack: bytes, needle: bytes) -> tuple[int, int]:
    count = 0
    first = -1
    start = 0
    while True:
        index = haystack.find(needle, start)
        if index < 0:
            return count, first
        if first < 0:
            first = index
        count += 1
        start = index + max(1, len(needle))


class Scanner:
    def __init__(self, rules: list[Rule], allowlist: list[dict[str, Any]], max_depth: int) -> None:
        self.rules = rules
        self.allowlist = allowlist
        self.max_depth = max_depth
        self.scanned_blobs = 0
        self.findings: list[Finding] = []
        self.errors: list[str] = []
        self.needs_lowercase = any(not rule.case_sensitive for rule in self.rules)

    def scan_target(self, target: Path) -> None:
        if target.is_dir():
            self.scan_directory(target)
            return
        self.scan_file(target, str(target), scan_path=False)

    def scan_directory(self, root: Path) -> None:
        for dirpath, _, filenames in os.walk(root):
            for filename in filenames:
                path = Path(dirpath) / filename
                try:
                    logical = str(path.relative_to(root.parent))
                except ValueError:
                    logical = str(path)
                self.scan_file(path, logical)

    def scan_file(self, path: Path, logical: str, scan_path: bool = True) -> None:
        if scan_path:
            self.scan_bytes(f"{logical}[path]", logical.encode("utf-8", "surrogateescape"))
        try:
            if is_archive_name(path.name) and zipfile.is_zipfile(path):
                self.scan_archive_bytes(path.read_bytes(), logical, depth=0)
            else:
                self.scan_bytes(logical, path.read_bytes())
        except OSError as exc:
            self.errors.append(f"{path}: unable to read file: {exc}")
        except zipfile.BadZipFile as exc:
            self.errors.append(f"{path}: invalid zip archive: {exc}")

    def scan_archive_file(self, path: Path, logical: str, depth: int) -> None:
        if depth > self.max_depth:
            self.errors.append(f"{logical}: exceeded nested archive depth {self.max_depth}")
            return
        try:
            with zipfile.ZipFile(path) as archive:
                self.scan_archive_members(archive, logical, depth)
        except (OSError, zipfile.BadZipFile, NotImplementedError) as exc:
            self.errors.append(f"{logical}: unable to read archive: {exc}")

    def scan_archive_bytes(self, data: bytes, logical: str, depth: int) -> None:
        if depth > self.max_depth:
            self.errors.append(f"{logical}: exceeded nested archive depth {self.max_depth}")
            return
        self.scan_bytes(f"{logical}[archive]", data)
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                self.scan_archive_members(archive, logical, depth)
        except zipfile.BadZipFile:
            return
        except NotImplementedError as exc:
            self.errors.append(f"{logical}: unsupported nested archive compression: {exc}")

    def scan_archive_members(self, archive: zipfile.ZipFile, logical: str, depth: int) -> None:
        for info in archive.infolist():
            entry_location = f"{logical}!{info.filename}"
            self.scan_bytes(
                f"{entry_location}[entry-name]",
                info.filename.encode("utf-8", "surrogateescape"),
            )
            if info.is_dir():
                continue
            try:
                data = archive.read(info)
            except (RuntimeError, OSError, zipfile.BadZipFile, NotImplementedError) as exc:
                self.errors.append(f"{entry_location}: unable to read archive entry: {exc}")
                continue
            if is_archive_name(info.filename) and zipfile.is_zipfile(io.BytesIO(data)):
                self.scan_archive_bytes(data, entry_location, depth + 1)
            else:
                self.scan_bytes(entry_location, data)

    def scan_bytes(self, location: str, data: bytes) -> None:
        self.scanned_blobs += 1
        lowered = data.lower() if self.needs_lowercase else data
        for rule in self.rules:
            haystack = data if rule.case_sensitive else lowered
            for needle in rule.needles:
                count, first = count_matches(haystack, needle.value)
                if count == 0:
                    continue
                finding = Finding(
                    location=location,
                    category=rule.category,
                    token=rule.token,
                    description=rule.description,
                    encoding=needle.encoding,
                    count=count,
                    first_offset=first,
                    excerpt=printable_excerpt(data, first),
                )
                if not finding_is_allowed(finding, self.allowlist):
                    self.findings.append(finding)


def is_archive_name(name: str) -> bool:
    return Path(name.lower()).suffix in ARCHIVE_SUFFIXES


def expand_targets(raw_paths: list[str], missing_ok: bool) -> tuple[list[Path], list[str]]:
    targets: list[Path] = []
    missing: list[str] = []
    for raw_path in raw_paths:
        matches: list[str]
        if glob.has_magic(raw_path):
            matches = glob.glob(raw_path, recursive=True)
        else:
            matches = [raw_path]
        existing = [Path(match) for match in matches if Path(match).exists()]
        if existing:
            targets.extend(existing)
        elif not missing_ok:
            missing.append(raw_path)
        else:
            missing.append(raw_path)

    deduped: list[Path] = []
    seen: set[str] = set()
    for target in targets:
        key = str(target.resolve())
        if key not in seen:
            seen.add(key)
            deduped.append(target)
    return deduped, missing


def build_parser(config: dict[str, Any] | None = None) -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Scan APK/AAB archives or unpacked build output for forbidden stealth identifiers."
    )
    parser.add_argument("paths", nargs="*", help="Artifact files, directories, or glob patterns to scan.")
    parser.add_argument(
        "--mode",
        default=os.environ.get("STEALTH_LEAKAGE_MODE", "stealth"),
        help="Scanner mode from the config. Defaults to STEALTH_LEAKAGE_MODE or 'stealth'.",
    )
    parser.add_argument(
        "--config",
        default=os.environ.get("STEALTH_LEAKAGE_CONFIG", str(DEFAULT_CONFIG)),
        help="Forbidden-token config JSON path.",
    )
    parser.add_argument(
        "--missing-ok",
        action="store_true",
        help="Exit successfully when requested targets are absent.",
    )
    parser.add_argument(
        "--max-depth",
        type=int,
        default=3,
        help="Maximum nested archive depth to inspect.",
    )
    parser.add_argument(
        "--max-findings",
        type=int,
        default=200,
        help="Maximum findings to print in text output.",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format.",
    )
    parser.add_argument(
        "--list-modes",
        action="store_true",
        help="List configured modes and exit.",
    )
    return parser


def print_text_result(mode: str, result: ScanResult, max_findings: int) -> None:
    if result.missing:
        if result.targets:
            print("Missing scan targets skipped:")
            for missing in result.missing:
                print(f"  - {missing}")
        else:
            print("No existing leakage scan targets found; skipped.")

    if result.errors:
        print("Scanner errors:", file=sys.stderr)
        for error in result.errors:
            print(f"  - {error}", file=sys.stderr)

    if not result.findings and not result.errors:
        if result.targets:
            joined = ", ".join(result.targets)
            print(
                f"Stealth leakage check passed for mode '{mode}' "
                f"({result.scanned_blobs} scanned blobs from {joined})."
            )
        return

    print(f"Forbidden identifiers found for mode '{mode}':")
    for finding in result.findings[:max_findings]:
        print(
            f"- {finding.category}: token {finding.token!r} "
            f"in {finding.location} ({finding.encoding}, {finding.count} match"
            f"{'' if finding.count == 1 else 'es'}, first offset {finding.first_offset})"
        )
        if finding.description:
            print(f"  reason: {finding.description}")
        print(f"  excerpt: {finding.excerpt}")

    if len(result.findings) > max_findings:
        remaining = len(result.findings) - max_findings
        print(f"... {remaining} additional finding(s) omitted. Re-run with --max-findings to show more.")


def result_as_json(mode: str, result: ScanResult) -> dict[str, Any]:
    return {
        "mode": mode,
        "targets": result.targets,
        "missing": result.missing,
        "scanned_blobs": result.scanned_blobs,
        "errors": result.errors,
        "findings": [dataclasses.asdict(finding) for finding in result.findings],
    }


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        config = load_config(Path(args.config))
        if args.list_modes:
            for mode in sorted(config["modes"]):
                print(mode)
            return 0
        categories, allowlist = resolve_mode(config, args.mode)
        rules = compile_rules(config, categories)
    except ConfigError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    env_paths = shlex.split(os.environ.get("STEALTH_LEAKAGE_PATHS", ""))
    raw_paths = args.paths or env_paths
    if not raw_paths:
        parser.error("provide at least one path or set STEALTH_LEAKAGE_PATHS")

    targets, missing = expand_targets(raw_paths, args.missing_ok)
    if missing and not args.missing_ok:
        print("error: missing scan target(s):", file=sys.stderr)
        for path in missing:
            print(f"  - {path}", file=sys.stderr)
        return 2

    scanner = Scanner(rules, allowlist, max_depth=args.max_depth)
    for target in targets:
        scanner.scan_target(target)

    result = ScanResult(
        targets=[str(target) for target in targets],
        missing=missing,
        scanned_blobs=scanner.scanned_blobs,
        findings=scanner.findings,
        errors=scanner.errors,
    )

    if args.format == "json":
        print(json.dumps(result_as_json(args.mode, result), indent=2, sort_keys=True))
    else:
        print_text_result(args.mode, result, args.max_findings)

    if result.errors:
        return 2
    if result.findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
