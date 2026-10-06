#!/usr/bin/env python3
"""Guard and render the staging-only Windows migration installer at build time."""

import argparse
import hashlib
import json
from pathlib import Path


ORDINARY_INSTALL = 'Filename: "{code:LanterndExecutablePath}"; Parameters: "install"; Flags: runhidden; Check: IsOrdinaryInstall'
MIGRATION_INSTALL = "if not Exec(LanterndExecutablePath(''), 'install', '', SW_HIDE,"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(environment, migration_e2e, build_type, auto_update_e2e):
    require(environment in ("prod", "staging"), "backend environment must be prod or staging")
    if environment == "staging" or migration_e2e:
        require(environment == "staging" and migration_e2e and auto_update_e2e and bool(build_type)
                and build_type.strip().lower() != "production",
                "staging backend requires migration_e2e, auto_update_e2e, and a non-production build")


def render(template, environment, migration_e2e, build_type, auto_update_e2e):
    validate(environment, migration_e2e, build_type, auto_update_e2e)
    if environment == "prod":
        return template
    require(template.count(ORDINARY_INSTALL) == 1 and template.count(MIGRATION_INSTALL) == 1,
            "expected exactly one ordinary and one migration service installation site")
    require("install --environment" not in template, "template already selects a service environment")
    rendered = template.replace(ORDINARY_INSTALL, ORDINARY_INSTALL.replace('Parameters: "install"', 'Parameters: "install --environment staging"'))
    rendered = rendered.replace(MIGRATION_INSTALL, MIGRATION_INSTALL.replace("'install'", "'install --environment staging'"))
    require(rendered.count("install --environment staging") == 2, "staging service command count differs")
    return rendered


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "render"))
    parser.add_argument("--backend-environment", choices=("prod", "staging"), required=True)
    parser.add_argument("--migration-e2e", choices=("true", "false"), required=True)
    parser.add_argument("--auto-update-e2e", choices=("true", "false"), required=True)
    parser.add_argument("--build-type", required=True)
    parser.add_argument("--template", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()
    migration = args.migration_e2e == "true"
    auto_update = args.auto_update_e2e == "true"
    validate(args.backend_environment, migration, args.build_type, auto_update)
    if args.command == "validate":
        return
    require(args.template and args.output and args.metadata, "render requires template, output, and metadata paths")
    original = args.template.read_bytes()
    rendered = render(original.decode("utf-8"), args.backend_environment, migration, args.build_type, auto_update).encode("utf-8")
    # Newlines and all unrelated template bytes are preserved, including on Windows.
    args.output.write_bytes(rendered)
    evidence = {
        "schema_version": 1,
        "backend_environment": args.backend_environment,
        "migration_e2e": migration,
        "auto_update_e2e": auto_update,
        "build_type": args.build_type,
        "service_install_arguments": "install --environment staging" if migration else "install",
        "dart_environment": "staging" if migration else "unchanged",
        "template_input_sha256": hashlib.sha256(original).hexdigest(),
        "template_output_sha256": hashlib.sha256(rendered).hexdigest(),
        "production_activation_ready": False,
    }
    args.metadata.write_text(json.dumps(evidence, indent=2) + "\n")


if __name__ == "__main__":
    main()
