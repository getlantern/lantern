#!/usr/bin/env python3
"""Render the production Inno template with isolated CI executables and identities."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from jinja2 import Environment, StrictUndefined


FIXTURE_APP_NAME = "Lantern Installer Migration Fixture"
FIXTURE_SERVICE_NAME = "LanternInstallerMigrationFixtureSvc"
FIXTURE_DATA_NAME = "LanternInstallerMigrationFixture"
FIXTURE_APP_ID = "0D48297B-A4BF-4D79-A39D-54712A3170DD"


def replace_once(pattern: str, replacement: str, text: str, description: str) -> str:
    replaced, count = re.subn(pattern, lambda _: replacement, text, flags=re.MULTILINE | re.DOTALL)
    if count != 1:
        raise ValueError(f"expected one {description}, found {count}")
    return replaced


def render_fixture(
    template: str,
    payload: Path,
    dependency: Path,
    install_directory: str = "C:\\Program Files\\" + FIXTURE_APP_NAME,
    fail_file_copy: bool = False,
) -> str:
    values = {
        "APP_ID": FIXTURE_APP_ID,
        "APP_VERSION": "10.0.0",
        "DISPLAY_NAME": FIXTURE_APP_NAME,
        "PUBLISHER_NAME": "Lantern installer CI",
        "PUBLISHER_URL": "https://github.com/getlantern/lantern",
        "OUTPUT_BASE_FILENAME": "lantern-migration-fixture",
        "SOURCE_DIR": str(payload.resolve()),
        "EXECUTABLE_NAME": "lantern.exe",
        "LOCALES": ["en"],
        "CREATE_DESKTOP_ICON": True,
    }
    environment = Environment(
        undefined=StrictUndefined,
        keep_trailing_newline=True,
        # Inno's {#...} expressions are not Jinja comments.
        comment_start_string="{##",
        comment_end_string="##}",
    )
    rendered = environment.from_string(template).render(values)
    rendered = replace_once(
        r'^#define SvcName[^\r\n]*$',
        f'#define SvcName "{FIXTURE_SERVICE_NAME}"',
        rendered,
        "service identity",
    )
    rendered = replace_once(
        r'^#define ProgramDataDir[^\r\n]*$',
        f'#define ProgramDataDir "{{commonappdata}}\\{FIXTURE_DATA_NAME}"',
        rendered,
        "fixture data directory",
    )
    rendered = replace_once(
        r'^#define ServiceInstallDir[^\r\n]*$',
        f'#define ServiceInstallDir "{install_directory}"',
        rendered,
        "fixture service installation directory",
    )
    # Preserve Dependency_PrepareToInstall, including the production migration
    # guard and dependency error handling. Only the prerequisite sources change.
    for procedure in ("Dependency_AddVC2015To2022", "Dependency_AddWebView2"):
        rendered = replace_once(
            rf"^procedure {procedure};\s*begin\n.*?^end;",
            f"""procedure {procedure};
begin
  if not FileExists(ExpandConstant('{{tmp}}\\fixture-dependency.exe')) then
    ExtractTemporaryFile('fixture-dependency.exe');
  Dependency_Add('fixture-dependency.exe', '', 'Fixture prerequisite', '', '', False, False);
end;""",
            rendered,
            procedure,
        )
    rendered = replace_once(
        r"^\[Files\]$",
        '[Files]\nSource: "' + str(dependency.resolve()) + '"; Flags: dontcopy',
        rendered,
        "files section",
    )
    if fail_file_copy:
        # This entry is deliberately after the production payload. A missing
        # external source produces an actual Inno copy error and rollback.
        rendered = replace_once(
            r"^\[Icons\]$",
            'Source: "{tmp}\\fixture-intentionally-missing.bin"; DestDir: "{app}"; '
            'ExternalSize: 1; Flags: external ignoreversion\n\n[Icons]',
            rendered,
            "file-copy failure boundary",
        )
    if "LegacyMigration" not in rendered or "ValidateInstallTarget" not in rendered:
        raise ValueError("production migration safeguards are absent")
    return rendered


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--payload", required=True, type=Path)
    parser.add_argument("--dependency", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--install-directory", default="C:\\Program Files\\" + FIXTURE_APP_NAME)
    parser.add_argument("--fail-file-copy", action="store_true")
    args = parser.parse_args()
    rendered = render_fixture(
        args.template.read_text(encoding="utf-8"), args.payload, args.dependency,
        args.install_directory, args.fail_file_copy
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()
