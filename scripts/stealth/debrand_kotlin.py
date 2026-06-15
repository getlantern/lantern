#!/usr/bin/env python3
"""Generate a de-branded COPY of the real Android Kotlin sources for Stealth.

Stealth builds must ship the REAL app, so the real handler layer under
``android/app/src/main/kotlin/org/getlantern/lantern/**`` has to be compiled
(not the legacy ``foundation.bridge`` stub). This script copies that tree into a
build directory with a mechanical, brand-neutral transform applied:

* package ``org.getlantern.lantern`` -> ``foundation.bridge`` (matches the
  stealth Android ``namespace`` so generated ``R``/``BuildConfig`` resolve), in
  both dotted (source) and slashed (path) forms;
* gomobile binding imports ``lantern.io.`` -> ``foundation.engine.`` (the
  stealth gomobile ``javapkg``);
* residual brand tokens ``getlantern`` -> ``foundation`` and ``Lantern``/
  ``lantern`` -> ``Bridge``/``bridge`` (covers class names that R8 keeps because
  they are referenced from the manifest, plus channel-name strings and log/dir
  paths). ``Vpn``/``VPN``/``TUN`` are intentionally preserved -- they are
  allowed in the stealth-vpn leakage policy.

The committed sources are never modified; only the generated copy is.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys


SOURCE_PACKAGE_DIR = "org/getlantern/lantern"
TARGET_PACKAGE_DIR = "foundation/bridge"

# Ordered, longest-match-first. The full own-package FQN must be rewritten to the
# exact ``foundation.bridge`` namespace BEFORE the generic ``getlantern``/
# ``lantern`` token rules run, otherwise piecewise substitution would yield
# ``org.foundation.bridge`` instead of ``foundation.bridge``.
TEXT_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    # The no-VPN service class/log-tag must NOT advertise its VPN heritage in a
    # stealth no-VPN build. Rename it to a neutral name BEFORE the brand rules
    # (otherwise "Lantern" -> "Backend" would leave "NoVpnBackendService", whose
    # "Vpn" token is visible in logcat and the manifest component name). Matches
    # the service's existing "Local connection" notification wording. Applied in
    # both modes; in stealth-vpn the (unused) class is renamed consistently.
    ("NoVpnLanternService", "LocalConnectionService"),
    ("org.getlantern.lantern", "foundation.bridge"),
    ("org/getlantern/lantern", "foundation/bridge"),
    ("lantern.io.", "foundation.engine."),
    ("lantern/io/", "foundation/engine/"),
    ("getlantern", "foundation"),
    ("GETLANTERN", "FOUNDATION"),
    # Generic brand tokens map to "Backend"/"backend" to match BOTH the Go ELF
    # sanitizer (NATIVE_TEXT_REPLACEMENTS) and the Dart-side run_flutter_build
    # mapping, so channel method names and any shared keys agree across all
    # layers. The package/channel FQN above stays foundation.bridge.
    ("Lantern", "Backend"),
    ("lantern", "backend"),
    ("LANTERN", "BACKEND"),
)


# OAuth gomobile exports are compiled out of stealth builds (//go:build !stealth
# in lantern-core/mobile), so these binding methods do not exist in the stealth
# AAR. The real MethodHandler calls them; OAuth is intentionally disabled in
# stealth (its Dart UI is removed by removeHighIdentificationUi), so the call
# sites are replaced with inert, correctly-typed stubs to keep Kotlin compiling.
OAUTH_STUB_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("Mobile.oAuthLoginUrl(provider)", '("" /* oauth disabled in stealth */)'),
    ("Mobile.oAuthLoginCallback(token)", '("{}" /* oauth disabled in stealth */)'),
    ("Mobile.isOAuthLogin()", "false /* oauth disabled in stealth */"),
    ("Mobile.getOAuthProvider()", '"" /* oauth disabled in stealth */'),
)


def debrand_text(text: str) -> str:
    for old, new in OAUTH_STUB_REPLACEMENTS:
        text = text.replace(old, new)
    for old, new in TEXT_REPLACEMENTS:
        text = text.replace(old, new)
    return text


def debrand_path(relative: str) -> str:
    # Apply the same token rules to the path so directory + filename are neutral
    # (e.g. service/LanternVpnService.kt -> service/BridgeVpnService.kt).
    return debrand_text(relative)


def generate(source_root: Path, output_root: Path) -> int:
    if not source_root.is_dir():
        print(f"error: source not found: {source_root}", file=sys.stderr)
        return 2
    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True, exist_ok=True)

    count = 0
    for src in sorted(source_root.rglob("*.kt")):
        relative = src.relative_to(source_root).as_posix()
        target = output_root / debrand_path(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(debrand_text(src.read_text(encoding="utf-8")), encoding="utf-8")
        count += 1
    print(f"de-branded {count} Kotlin file(s) -> {output_root}")
    return 0


RES_TEXT_SUFFIXES = {".xml"}


def generate_res(res_source: Path, res_overlay: Path | None, res_output: Path) -> int:
    """De-brand a copy of the real res tree, then overlay stealth res on top.

    The real handlers reference a small number of resources (e.g. the
    notification icon). Stealth builds previously shipped only the 4-file
    ``src/stealth/res`` overlay, which is insufficient for the real code. We
    de-brand a full copy of ``src/main/res`` (renaming brand resource files and
    substituting brand text in values) and then copy the stealth overlay over it
    (last-writer-wins), avoiding duplicate-resource merge conflicts.
    """
    if not res_source.is_dir():
        print(f"error: res source not found: {res_source}", file=sys.stderr)
        return 2
    if res_output.exists():
        shutil.rmtree(res_output)
    res_output.mkdir(parents=True, exist_ok=True)

    for src in sorted(res_source.rglob("*")):
        if src.is_dir():
            continue
        relative = debrand_path(src.relative_to(res_source).as_posix())
        target = res_output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if src.suffix.lower() in RES_TEXT_SUFFIXES:
            target.write_text(debrand_text(src.read_text(encoding="utf-8")), encoding="utf-8")
        else:
            shutil.copy2(src, target)

    if res_overlay and res_overlay.is_dir():
        for src in sorted(res_overlay.rglob("*")):
            if src.is_dir():
                continue
            relative = src.relative_to(res_overlay).as_posix()
            target = res_output / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, target)  # overlay wins, no de-brand (already neutral)
    print(f"merged de-branded res -> {res_output}")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=Path("android/app/src/main/kotlin") / SOURCE_PACKAGE_DIR,
        help="Real Kotlin package root to de-brand.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
        help="Output directory root for the de-branded copy (the foundation/bridge tree is written under here).",
    )
    parser.add_argument("--res-source", type=Path, help="Real res tree to de-brand (e.g. android/app/src/main/res).")
    parser.add_argument("--res-overlay", type=Path, help="Stealth res overlay copied on top (e.g. android/app/src/stealth/res).")
    parser.add_argument("--res-output", type=Path, help="Output dir for the merged de-branded res tree.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    output_pkg_root = args.output / TARGET_PACKAGE_DIR
    rc = generate(args.source, output_pkg_root)
    if rc != 0:
        return rc
    if args.res_source and args.res_output:
        rc = generate_res(args.res_source, args.res_overlay, args.res_output)
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
