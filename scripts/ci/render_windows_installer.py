#!/usr/bin/env python3
"""Package an already-built Windows payload without invoking Flutter again."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from jinja2 import Environment, StrictUndefined
import yaml


def render(template: str, config: dict, version: str, source: Path,
           output_name: str, signed: bool) -> str:
    # These are the substitutions used by Fastforge's Inno template renderer.
    # Compile the result directly with ISCC: `fastforge package --skip-clean`
    # still rebuilds Flutter and replaces the signed binaries.
    values = {
        "APP_ID": config["app_id"],
        "APP_VERSION": version,
        "DISPLAY_NAME": config["display_name"],
        "PUBLISHER_NAME": config["publisher"],
        "PUBLISHER_URL": config["publisher_url"],
        "EXECUTABLE_NAME": config["executable_name"],
        "CREATE_DESKTOP_ICON": config.get("create_desktop_icon", False),
        "LOCALES": config.get("locales", ["en"]),
        "SOURCE_DIR": str(source.resolve()),
        "OUTPUT_BASE_FILENAME": output_name,
    }
    for key, value in values.items():
        if isinstance(value, str) and any(char in value for char in ('\r', '\n', '"')):
            raise ValueError(f"Unsafe Inno Setup value: {key}")
    environment = Environment(
        undefined=StrictUndefined,
        keep_trailing_newline=True,
        # Preserve Inno's {#...} preprocessor expressions.
        comment_start_string="{##",
        comment_end_string="##}",
    )
    rendered = environment.from_string(template).render(values)
    if signed:
        # The named tool is supplied on the ISCC command line. Inno signs both
        # setup and the uninstaller, including setup's temporary self-copies.
        rendered, count = re.subn(
            r"(?m)^\[Setup\]$",
            "[Setup]\nSignTool=lantern\nSignedUninstaller=yes",
            rendered,
        )
        if count != 1:
            raise ValueError(f"Expected one Inno [Setup] section, found {count}")
    return rendered


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output-name", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--signed", action="store_true")
    args = parser.parse_args()
    config = yaml.safe_load(args.config.read_text(encoding="utf-8"))
    if not isinstance(config, dict):
        raise ValueError(f"Invalid installer config {args.config}: expected a YAML mapping")
    required = {"app_id", "display_name", "publisher", "publisher_url", "executable_name"}
    missing = sorted(required - config.keys())
    if missing:
        raise ValueError(f"Invalid installer config {args.config}: missing keys: {', '.join(missing)}")
    if not args.source.is_dir():
        raise ValueError(f"Missing built Windows payload: {args.source}")
    result = render(args.template.read_text(encoding="utf-8"), config,
                    args.version, args.source, args.output_name, args.signed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Match Fastforge's BOM so Inno reads localized messages as UTF-8.
    args.output.write_text(result, encoding="utf-8-sig")


if __name__ == "__main__":
    main()
