#!/usr/bin/env python3
"""Run a Flutter build with de-branded assets for Stealth artifacts.

The real application is compiled (real pubspec, real dependency graph, real
``lib/main.dart``). De-branding is applied as a *pre-compile transform* over
backed-up copies of the working tree, then restored after the build:
``msgstr`` translation text and brand URLs in the locale assets, brand
substrings in Dart sources (``debrand_dart_sources``), and brand image asset
names/contents (``rename_brand_assets``). The committed source is restored
afterward, and the build does NOT swap in a minimal pubspec.

Locale message *keys* (``msgid``) are intentionally left untouched here so that
runtime ``'<key>'.i18n`` lookups still resolve. Residual brand substrings that
survive in the message keys and in the compiled ``libapp.so`` are handled by the
post-compile artifact sanitizer + leakage gate, not by this wrapper.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from typing import Iterable


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


# --- De-branding -----------------------------------------------------------

# Any URL/host/handle that carries the brand is replaced wholesale with a
# neutral equivalent so no brand substring survives in visible copy.
_URL_NEUTRAL = "example.com"
# Only fires on genuine URL / host / handle contexts that carry the brand, so a
# standalone brand word is left for the product-name replacement below.
_BRAND_URL_RE = re.compile(
    r"""(?xi)
      https?://[\w.-]*(?:get)?lantern[\w./?=%&:+_-]*    # full scheme URL
    | (?:[\w-]+\.)*(?:get)?lantern\.[a-z]{2,}[\w./?=%&:+_-]*  # host: lantern.io, support.lantern.io, s3.../lantern.io/...
    | (?:t\.me|twitter\.com|instagram\.com)/[\w]*lantern[\w]*  # social paths
    | @[\w]*lantern[\w]*                                # @handles
    """
)


def neutralize_brand_urls(text: str) -> str:
    """Replace any URL/host/handle containing the brand with a neutral host."""

    def repl(match: re.Match[str]) -> str:
        token = match.group(0)
        if token.lower().startswith("http"):
            return "https://" + _URL_NEUTRAL
        if token.startswith("@"):
            return "@app"
        return _URL_NEUTRAL

    return _BRAND_URL_RE.sub(repl, text)


def _replace_brand_word(text: str, neutral: str) -> str:
    """Case-aware replacement of the standalone brand word with ``neutral``.

    ``getlantern`` is handled before ``lantern`` so the inner match is not
    processed twice.
    """

    def make_repl(replacement: str):
        def repl(match: re.Match[str]) -> str:
            token = match.group(0)
            if token.isupper():
                return replacement.upper()
            if token[:1].isupper():
                return replacement[:1].upper() + replacement[1:]
            return replacement

        return repl

    text = re.sub(r"getlantern", make_repl(neutral), text, flags=re.IGNORECASE)
    text = re.sub(r"lantern", make_repl(neutral), text, flags=re.IGNORECASE)
    return text


# In stealth-novpn the app is a local SOCKS proxy, not a VPN, so visible "VPN"
# wording is reworded to "Proxy" (e.g. "VPN Status" -> "Proxy Status",
# "Turn on VPN" -> "Turn on Proxy"). Case-preserving; applied only to msgstr
# values for novpn builds.
def _reword_vpn_to_proxy(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        token = match.group(0)
        if token == "VPN":
            return "Proxy"
        if token == "vpn":
            return "proxy"
        return "Proxy"  # "Vpn"

    return re.sub(r"VPN|Vpn|vpn", repl, text)


def debrand_visible(text: str, product_name: str, is_novpn: bool = False) -> str:
    """De-brand a visible translation value: neutralize brand URLs then brand words."""
    text = neutralize_brand_urls(text)
    text = _replace_brand_word(text, product_name)
    if is_novpn:
        text = _reword_vpn_to_proxy(text)
    return text


# Ordered brand-token rules for NON-visible text: Dart string-literal contents,
# .po message KEYS (msgid) and translator comments. Length need not be preserved
# (libapp.so is no longer ELF-scrubbed). The full channel/package FQN is rewritten
# first so it maps to the exact foundation.bridge namespace the Kotlin side uses,
# before the generic token rules. MUST stay in sync with debrand_kotlin.py so
# i18n keys + channel names match across the Dart and Kotlin halves.
# The generic token rules MUST match the Go ELF sanitizer's NATIVE_TEXT_REPLACEMENTS
# (Lantern->Backend, lantern->backend, getlantern->foundation) so that brand strings
# crossing the Dart<->Go FFI boundary stay consistent -- e.g. the Go struct tag
# json:"isLantern" is scrubbed to "isBackend" in libgojni.so, and the Dart literal
# json['isLantern'] must de-brand to the same "isBackend". The package/channel FQN
# is special-cased to foundation.bridge (Kotlin<->Dart only) and rewritten first.
_TOKEN_REPLACEMENTS = (
    ("org.getlantern.lantern", "foundation.bridge"),
    ("org/getlantern/lantern", "foundation/bridge"),
    ("getlantern", "foundation"),
    ("GETLANTERN", "FOUNDATION"),
    ("Lantern", "Backend"),
    ("lantern", "backend"),
    ("LANTERN", "BACKEND"),
)


def debrand_tokens(text: str) -> str:
    for old, new in _TOKEN_REPLACEMENTS:
        text = text.replace(old, new)
    return text


_MSGSTR_RE = re.compile(r'^(msgstr(?:\[\d+\])?\s+)"(.*)"\s*$')
_CONT_RE = re.compile(r'^"(.*)"\s*$')


def debrand_po_text(content: str, product_name: str, is_novpn: bool = False) -> str:
    """De-brand a gettext ``.po`` document.

    ``msgstr`` values (what the user sees) use the product-name substitution;
    everything else -- ``msgid`` KEYS and translator comments -- uses the brand
    token rules so the keys match the de-branded Dart key literals and no brand
    survives in the shipped ``.po`` asset.
    """
    out: list[str] = []
    in_msgstr = False
    for line in content.splitlines():
        msgstr_match = _MSGSTR_RE.match(line)
        if msgstr_match:
            in_msgstr = True
            prefix, value = msgstr_match.group(1), msgstr_match.group(2)
            out.append(f'{prefix}"{debrand_visible(value, product_name, is_novpn)}"')
            continue
        if in_msgstr:
            cont_match = _CONT_RE.match(line)
            if cont_match:
                value = cont_match.group(1)
                out.append(f'"{debrand_visible(value, product_name, is_novpn)}"')
                continue
            in_msgstr = False
        out.append(debrand_tokens(line))
    trailing_newline = "\n" if content.endswith("\n") else ""
    return "\n".join(out) + trailing_newline


# Matches Dart string literals (triple-quoted, single, double). Brand tokens are
# rewritten only INSIDE these literals so identifiers are left to --obfuscate and
# code is not broken. Import URIs (package:/dart:) are skipped so package paths
# stay intact (they are resolved at compile time and do not leak into libapp.so).
_DART_STRING_RE = re.compile(
    r"'''(?:\\.|(?!''').)*?'''"
    r'|"""(?:\\.|(?!""").)*?"""'
    r"|'(?:\\.|[^'\\\n])*'"
    r'|"(?:\\.|[^"\\\n])*"',
    re.DOTALL,
)
_IMPORT_URI_PREFIXES = ("package:", "dart:")
# Dart string interpolations reference real identifiers/expressions; their
# contents must NOT be de-branded (e.g. '$lanternServiceProvider' is a code ref,
# not brand text). They are extracted and restored verbatim around de-branding.
_INTERP_RE = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")


# Brand identifiers that survive --obfuscate because they are exposed at runtime
# (e.g. enum value names via `.name`), so they leak into libapp.so. Renamed
# whole-string across the build copy of lib/ (unique camelCase tokens that do not
# occur in package paths). Mapping matches the generic backend rule + Go scrub.
_IDENTIFIER_REPLACEMENTS = (
    ("lanternLocation", "backendLocation"),
    ("lanternProLicense", "backendProLicense"),
)


def _debrand_dart_literal(match: re.Match[str]) -> str:
    literal = match.group(0)
    inner = literal.strip("'\"")
    # Skip import/part/export URIs: package:/dart: imports and relative ".dart"
    # paths. Those literals point at files that are NOT renamed, so de-branding
    # them would break compilation; they also do not leak into libapp.so.
    if inner.startswith(_IMPORT_URI_PREFIXES) or inner.endswith(".dart"):
        return literal
    out: list[str] = []
    pos = 0
    for interp in _INTERP_RE.finditer(literal):
        out.append(debrand_tokens(literal[pos:interp.start()]))
        token = interp.group(0)
        if token.startswith("${"):
            # Recurse: de-brand string literals nested in the ${...} expression
            # (e.g. ${'return_to_lantern'.i18n}) while preserving identifiers.
            out.append("${" + debrand_dart_source(token[2:-1]) + "}")
        else:
            out.append(token)  # bare $identifier reference -- leave intact
        pos = interp.end()
    out.append(debrand_tokens(literal[pos:]))
    return "".join(out)


# i18n keys are referenced as a quoted string immediately followed by `.i18n`.
# Matching this local pattern de-brands keys robustly even when the literal is
# nested inside a same-quote interpolation (e.g. '${'return_to_lantern'.i18n}'),
# which the general string-literal regex cannot tokenize. Keys de-brand with the
# token rules, matching the de-branded .po msgids.
_I18N_KEY_RE = re.compile(r"""(['"])([A-Za-z0-9_]+)\1(?=\s*\.i18n)""")


def _debrand_i18n_key(match: re.Match[str]) -> str:
    quote, key = match.group(1), match.group(2)
    return f"{quote}{debrand_tokens(key)}{quote}"


def debrand_dart_source(text: str) -> str:
    """De-brand Dart: leaking identifiers, i18n keys, then string-literal contents."""
    for old, new in _IDENTIFIER_REPLACEMENTS:
        text = text.replace(old, new)
    text = _I18N_KEY_RE.sub(_debrand_i18n_key, text)
    return _DART_STRING_RE.sub(_debrand_dart_literal, text)


def debrand_dart_sources(root: Path, backup_root: Path) -> list[Path]:
    """Rewrite brand tokens inside string literals across lib/ build copies.

    Covers the native-channel prefix (-> foundation.bridge, matching Kotlin),
    i18n key literals (matching the de-branded .po msgids), asset-path constants,
    hardcoded URLs, and log/toString strings. Committed sources are restored.
    """
    modified: list[Path] = []
    for source in sorted((root / "lib").rglob("*.dart")):
        original = source.read_text(encoding="utf-8")
        debranded = debrand_dart_source(original)
        if debranded == original:
            continue
        relative = source.relative_to(root)
        backup_target = backup_root / relative
        backup_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, backup_target)
        source.write_text(debranded, encoding="utf-8")
        modified.append(relative)
    return modified


# Asset directories whose brand-named files must be renamed (pubspec uses
# directory globs, so AssetManifest picks up the renamed files automatically and
# no pubspec edit is needed). The renamed paths match the de-branded Dart
# asset-path literals (e.g. assets/images/lantern_logo.svg -> bridge_logo.svg).
_ASSET_DIRS = ("assets/images",)

# Brand LOGO/wordmark assets draw the Lantern mark as vector paths, so renaming
# the file is not enough -- the graphic itself must be replaced with a neutral
# one (otherwise the brand logo still shows on screen). Keyed by ORIGINAL name.
_WORDMARK_LOGOS = {"lantern_logo.svg", "lantern_pro.svg", "lantern_chinese.svg", "lantern_pro_chinese.svg"}
_ROUND_LOGOS = {"lantern_logo_round.svg"}


def _wordmark_svg(product_name: str) -> str:
    text = product_name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    # Size the text to fit the 107x20 viewBox the LanternLogo widget expects.
    font_size = min(13.0, 100.0 / max(1, len(product_name)) / 0.55)
    return (
        '<svg width="107" height="20" viewBox="0 0 107 20" fill="none" '
        'xmlns="http://www.w3.org/2000/svg">'
        f'<text x="53.5" y="15" font-family="sans-serif" font-size="{font_size:.1f}" '
        f'font-weight="700" text-anchor="middle" fill="#000000">{text}</text></svg>\n'
    )


def _round_logo_svg() -> str:
    # Neutral globe-style mark, same 24x24 viewBox as the round brand logo.
    return (
        '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" '
        'xmlns="http://www.w3.org/2000/svg">'
        '<circle cx="12" cy="12" r="11" fill="#00838F"/>'
        '<circle cx="12" cy="12" r="6.5" fill="none" stroke="#ffffff" stroke-width="1.5"/>'
        '<line x1="2" y1="12" x2="22" y2="12" stroke="#ffffff" stroke-width="1.5"/>'
        '<path d="M12 1.5 C7 7 7 17 12 22.5 C17 17 17 7 12 1.5 Z" fill="none" '
        'stroke="#ffffff" stroke-width="1.5"/></svg>\n'
    )


def _neutral_logo_content(original_name: str, product_name: str) -> str | None:
    if original_name in _WORDMARK_LOGOS:
        return _wordmark_svg(product_name)
    if original_name in _ROUND_LOGOS:
        return _round_logo_svg()
    return None


def rename_brand_assets(root: Path, product_name: str, backup_root: Path) -> tuple[list[Path], list[Path]]:
    """Rename brand-named asset files; replace brand LOGO graphics with neutral ones.

    Returns (backed_up_originals, created_paths)."""
    backed_up: list[Path] = []
    created: list[Path] = []
    for asset_dir in _ASSET_DIRS:
        directory = root / asset_dir
        if not directory.is_dir():
            continue
        for source in sorted(directory.iterdir()):
            if not source.is_file():
                continue
            new_name = debrand_tokens(source.name)
            if new_name == source.name:
                continue
            relative = source.relative_to(root)
            backup_target = backup_root / relative
            backup_target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, backup_target)
            new_path = source.with_name(new_name)
            neutral = _neutral_logo_content(source.name, product_name)
            if neutral is not None:
                # Replace the brand graphic with a neutral logo under the new name.
                new_path.write_text(neutral, encoding="utf-8")
                source.unlink()
            else:
                source.rename(new_path)
            backed_up.append(relative)
            created.append(new_path.relative_to(root))
    return backed_up, created


def debrand_locales(root: Path, product_name: str, is_novpn: bool, backup_root: Path) -> list[Path]:
    """Rewrite ``assets/locales/*.po`` in place; return list of backed-up files."""
    locale_dir = root / "assets/locales"
    modified: list[Path] = []
    for source in sorted(locale_dir.glob("*.po")):
        original = source.read_text(encoding="utf-8")
        debranded = debrand_po_text(original, product_name, is_novpn)
        if debranded == original:
            continue
        relative = source.relative_to(root)
        backup_target = backup_root / relative
        backup_target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, backup_target)
        source.write_text(debranded, encoding="utf-8")
        modified.append(relative)
    return modified


def restore_files(root: Path, backup_root: Path, modified: list[Path]) -> None:
    for relative in modified:
        backup_source = backup_root / relative
        target = root / relative
        if backup_source.exists():
            shutil.copy2(backup_source, target)


def run(cmd: list[str], root: Path) -> int:
    print("Running de-branded Flutter build:", " ".join(cmd), flush=True)
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
    product_name = str(profile.get("appName") or "Secure Browser")
    is_novpn = str(profile.get("mode") or "") in ("stealth-novpn", "novpn")

    backup_root = root / "build/mobile/flutter-backup"
    if backup_root.exists():
        shutil.rmtree(backup_root)
    backup_root.mkdir(parents=True, exist_ok=True)

    modified: list[Path] = []
    created: list[Path] = []
    try:
        modified += debrand_locales(root, product_name, is_novpn, backup_root)
        print(f"De-branded {len(modified)} locale file(s) for '{product_name}'.", flush=True)
        dart_modified = debrand_dart_sources(root, backup_root)
        modified += dart_modified
        print(f"De-branded string literals in {len(dart_modified)} Dart file(s).", flush=True)
        asset_backed_up, asset_created = rename_brand_assets(root, product_name, backup_root)
        modified += asset_backed_up
        created += asset_created
        print(f"Renamed {len(asset_created)} brand-named asset file(s).", flush=True)
        return run(args.command, root)
    finally:
        for relative in created:
            (root / relative).unlink(missing_ok=True)
        restore_files(root, backup_root, modified)
        shutil.rmtree(backup_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
