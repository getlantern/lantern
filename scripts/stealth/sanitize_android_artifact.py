#!/usr/bin/env python3
"""Remove metadata that must not ship in Stealth Android artifacts."""

from __future__ import annotations

import argparse
import dataclasses
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile


STRIP_ENTRIES = {
    "BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map",
}


NATIVE_TEXT_REPLACEMENTS = (
    (b"android.net.VpnService", b"android.net.NetService"),
    (b"BIND_VPN_SERVICE", b"BIND_NET_SERVICE"),
    (b"FOREGROUND_SERVICE_SYSTEM_EXEMPTED", b"FOREGROUND_SERVICE_NETWRK_EXEMPTED"),
    (b"LanternVpnService", b"BackendNetService"),
    (b"LanternVPN", b"BackendNET"),
    (b"LanternVpn", b"BackendNet"),
    (b"getlantern", b"foundation"),
    (b"GETLANTERN", b"FOUNDATION"),
    (b"Lantern", b"Backend"),
    (b"lantern", b"backend"),
    (b"LANTERN", b"BACKEND"),
    (b"VpnService", b"NetService"),
    (b"vpnservice", b"netservice"),
    (b"VPNSERVICE", b"NETSERVICE"),
    (b"TunOptions", b"NetOptions"),
    (b"tun2socks", b"net2sockx"),
    (b"VPN", b"NET"),
    (b"Vpn", b"Net"),
    (b"vpn", b"net"),
    (b"TUN", b"NET"),
    (b"Tun", b"Net"),
)

for old, new in NATIVE_TEXT_REPLACEMENTS:
    if len(old) != len(new):
        raise ValueError(f"native scrub replacement length mismatch: {old!r} -> {new!r}")

PRINTABLE_ASCII = frozenset(range(0x20, 0x7F)) | {0x09, 0x0A, 0x0D}
ELF_TEXT_SECTION_NAMES = {
    ".data.rel.ro",
    ".debug_line_str",
    ".debug_str",
    ".go.buildinfo",
    ".gopclntab",
    ".rodata",
}
ELF_LINKAGE_SECTION_NAMES = {
    ".dynstr",
    ".shstrtab",
    ".strtab",
}
SIGNING_STORE_PASSWORD_ENV = "STEALTH_ANDROID_STORE_PASSWORD"
SIGNING_KEY_PASSWORD_ENV = "STEALTH_ANDROID_KEY_PASSWORD"


@dataclasses.dataclass(frozen=True)
class SanitizeResult:
    removed_metadata_entries: int = 0
    scrubbed_native_strings: int = 0
    resigned: bool = False


@dataclasses.dataclass(frozen=True)
class SigningConfig:
    keystore: Path
    store_password: str
    key_alias: str
    key_password: str


def is_native_library(filename: str) -> bool:
    normalized = filename.replace("\\", "/")
    return normalized.endswith(".so") and "/lib/" in f"/{normalized}"


def scrub_native_text(data: bytes) -> tuple[bytes, int]:
    if data.startswith(b"\x7fELF"):
        return scrub_elf_text_sections(data)
    output = bytearray(data)
    replacements = scrub_text_range(output, 0, len(output))
    if replacements == 0:
        return data, 0
    return bytes(output), replacements


def scrub_text_range(output: bytearray, range_start: int, range_end: int) -> int:
    replacements = 0
    start: int | None = None

    def scrub_run(end: int) -> None:
        nonlocal replacements
        if start is None or end - start < 3:
            return
        original = bytes(output[start:end])
        scrubbed = original
        for old, new in NATIVE_TEXT_REPLACEMENTS:
            count = scrubbed.count(old)
            if count:
                replacements += count
                scrubbed = scrubbed.replace(old, new)
        if scrubbed != original:
            output[start:end] = scrubbed

    for index in range(range_start, range_end):
        byte = output[index]
        if byte in PRINTABLE_ASCII:
            if start is None:
                start = index
            continue
        scrub_run(index)
        start = None
    scrub_run(range_end)
    return replacements


def scrub_elf_text_sections(data: bytes) -> tuple[bytes, int]:
    sections = elf_sections(data)
    if not sections:
        return data, 0
    output = bytearray(data)
    replacements = 0
    for name, offset, size in sections:
        if name in ELF_LINKAGE_SECTION_NAMES:
            continue
        if name not in ELF_TEXT_SECTION_NAMES and not name.startswith(".debug"):
            continue
        if offset < 0 or size < 0 or offset + size > len(output):
            continue
        replacements += scrub_text_range(output, offset, offset + size)
    if replacements == 0:
        return data, 0
    return bytes(output), replacements


def elf_sections(data: bytes) -> list[tuple[str, int, int]]:
    if len(data) < 0x34 or not data.startswith(b"\x7fELF"):
        return []
    elf_class = data[4]
    endian_flag = data[5]
    if endian_flag == 1:
        endian = "<"
    elif endian_flag == 2:
        endian = ">"
    else:
        return []

    try:
        if elf_class == 1:
            e_shoff = struct.unpack_from(endian + "I", data, 32)[0]
            e_shentsize = struct.unpack_from(endian + "H", data, 46)[0]
            e_shnum = struct.unpack_from(endian + "H", data, 48)[0]
            e_shstrndx = struct.unpack_from(endian + "H", data, 50)[0]
            section_struct = endian + "IIIIIIIIII"
        elif elf_class == 2:
            e_shoff = struct.unpack_from(endian + "Q", data, 40)[0]
            e_shentsize = struct.unpack_from(endian + "H", data, 58)[0]
            e_shnum = struct.unpack_from(endian + "H", data, 60)[0]
            e_shstrndx = struct.unpack_from(endian + "H", data, 62)[0]
            section_struct = endian + "IIQQQQIIQQ"
        else:
            return []
    except struct.error:
        return []

    if e_shoff <= 0 or e_shentsize <= 0 or e_shnum <= 0 or e_shstrndx >= e_shnum:
        return []

    raw_sections: list[tuple[int, int, int]] = []
    for index in range(e_shnum):
        offset = e_shoff + index * e_shentsize
        if offset + e_shentsize > len(data):
            return []
        try:
            fields = struct.unpack_from(section_struct, data, offset)
        except struct.error:
            return []
        name_offset = fields[0]
        section_offset = fields[4]
        section_size = fields[5]
        raw_sections.append((name_offset, section_offset, section_size))

    _, shstr_offset, shstr_size = raw_sections[e_shstrndx]
    if shstr_offset < 0 or shstr_size < 0 or shstr_offset + shstr_size > len(data):
        return []
    shstr = data[shstr_offset : shstr_offset + shstr_size]

    sections: list[tuple[str, int, int]] = []
    for name_offset, section_offset, section_size in raw_sections:
        if name_offset >= len(shstr):
            name = ""
        else:
            end = shstr.find(b"\x00", name_offset)
            if end < 0:
                end = len(shstr)
            name = shstr[name_offset:end].decode("utf-8", "replace")
        sections.append((name, int(section_offset), int(section_size)))
    return sections


def sanitize_zip(path: Path, resign: bool = False, allow_debug_keystore: bool = False) -> SanitizeResult:
    if not path.exists():
        raise FileNotFoundError(path)

    removed = 0
    scrubbed = 0
    with tempfile.NamedTemporaryFile(
        prefix=f"{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
        delete=False,
    ) as handle:
        tmp = Path(handle.name)

    try:
        with zipfile.ZipFile(path, "r") as source, zipfile.ZipFile(
            tmp, "w", compression=zipfile.ZIP_DEFLATED
        ) as target:
            for info in source.infolist():
                if info.filename in STRIP_ENTRIES:
                    removed += 1
                    continue
                data = source.read(info.filename)
                if is_native_library(info.filename):
                    data, replacements = scrub_native_text(data)
                    scrubbed += replacements
                out = zipfile.ZipInfo(info.filename, date_time=info.date_time)
                out.compress_type = info.compress_type
                out.comment = info.comment
                out.extra = info.extra
                out.internal_attr = info.internal_attr
                out.external_attr = info.external_attr
                target.writestr(out, data)
        shutil.move(str(tmp), path)
    finally:
        tmp.unlink(missing_ok=True)
    resigned = False
    if resign and (removed or scrubbed):
        resign_android_artifact(path, allow_debug_keystore=allow_debug_keystore)
        resigned = True
    return SanitizeResult(
        removed_metadata_entries=removed,
        scrubbed_native_strings=scrubbed,
        resigned=resigned,
    )


def resign_android_artifact(path: Path, allow_debug_keystore: bool = False) -> None:
    suffix = path.suffix.lower()
    signing = signing_config(allow_debug_keystore=allow_debug_keystore)
    signing_env = os.environ.copy()
    signing_env[SIGNING_STORE_PASSWORD_ENV] = signing.store_password
    signing_env[SIGNING_KEY_PASSWORD_ENV] = signing.key_password
    if suffix == ".apk":
        zipalign, apksigner = android_signing_tools()
        aligned = path.with_suffix(path.suffix + ".aligned")
        signed = path.with_suffix(path.suffix + ".signed")
        try:
            subprocess.run([str(zipalign), "-p", "-f", "4", str(path), str(aligned)], check=True)
            subprocess.run(
                [
                    str(apksigner),
                    "sign",
                    "--ks",
                    str(signing.keystore),
                    "--ks-key-alias",
                    signing.key_alias,
                    "--ks-pass",
                    f"env:{SIGNING_STORE_PASSWORD_ENV}",
                    "--key-pass",
                    f"env:{SIGNING_KEY_PASSWORD_ENV}",
                    "--out",
                    str(signed),
                    str(aligned),
                ],
                check=True,
                env=signing_env,
            )
            shutil.move(str(signed), path)
        finally:
            aligned.unlink(missing_ok=True)
            signed.unlink(missing_ok=True)
        return
    if suffix == ".aab":
        signed = path.with_suffix(path.suffix + ".signed")
        try:
            subprocess.run(
                [
                    "jarsigner",
                    "-keystore",
                    str(signing.keystore),
                    "-signedjar",
                    str(signed),
                    str(path),
                    signing.key_alias,
                ],
                check=True,
                input=f"{signing.store_password}\n{signing.key_password}\n",
                text=True,
            )
            shutil.move(str(signed), path)
        finally:
            signed.unlink(missing_ok=True)


def signing_config(allow_debug_keystore: bool = False) -> SigningConfig:
    env = os.environ
    if all(env.get(name) for name in ("KEYSTORE_FILE", "KEYSTORE_PWD", "KEY_ALIAS", "KEY_PWD")):
        return SigningConfig(
            keystore=Path(env["KEYSTORE_FILE"]),
            store_password=env["KEYSTORE_PWD"],
            key_alias=env["KEY_ALIAS"],
            key_password=env["KEY_PWD"],
        )
    if not allow_debug_keystore:
        raise RuntimeError(
            "KEYSTORE_FILE, KEYSTORE_PWD, KEY_ALIAS, and KEY_PWD are required for --resign "
            "(use --allow-debug-keystore only for local test builds)"
        )
    return SigningConfig(
        keystore=Path.home() / ".android" / "debug.keystore",
        store_password="android",
        key_alias="androiddebugkey",
        key_password="android",
    )


def android_signing_tools() -> tuple[Path, Path]:
    sdk_root = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    if not sdk_root:
        raise RuntimeError("ANDROID_SDK_ROOT or ANDROID_HOME is required to re-sign APKs")
    build_tools = Path(sdk_root) / "build-tools"
    candidates = sorted(build_tools.glob("*/apksigner"), key=android_build_tools_version_key)
    if not candidates:
        raise RuntimeError(f"unable to find apksigner under {build_tools}")
    apksigner = candidates[-1]
    zipalign = apksigner.with_name("zipalign")
    if not zipalign.exists():
        raise RuntimeError(f"unable to find zipalign next to {apksigner}")
    return zipalign, apksigner


def android_build_tools_version_key(apksigner: Path) -> tuple[int, int, int, int, int, str]:
    version = apksigner.parent.name
    main, separator, suffix = version.partition("-")
    parts = []
    for raw in main.split("."):
        parts.append(int(raw) if raw.isdigit() else -1)
    while len(parts) < 3:
        parts.append(0)
    stable = 1 if not separator else 0
    rc = -1
    if suffix.startswith("rc") and suffix[2:].isdigit():
        rc = int(suffix[2:])
    return parts[0], parts[1], parts[2], stable, rc, version


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resign", action="store_true", help="Re-sign APK/AAB artifacts after mutation.")
    parser.add_argument(
        "--allow-debug-keystore",
        action="store_true",
        help="Allow Android's debug keystore when release signing env vars are absent.",
    )
    parser.add_argument("artifacts", nargs="+", type=Path)
    args = parser.parse_args(argv)

    try:
        results = [
            (artifact, sanitize_zip(artifact, resign=args.resign, allow_debug_keystore=args.allow_debug_keystore))
            for artifact in args.artifacts
        ]
    except (FileNotFoundError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"sanitize_android_artifact.py: {exc}", file=sys.stderr)
        return 1

    for artifact, result in results:
        if result.removed_metadata_entries or result.scrubbed_native_strings:
            print(
                f"Sanitized {artifact}: removed {result.removed_metadata_entries} metadata entries, "
                f"scrubbed {result.scrubbed_native_strings} native strings"
                f"{', re-signed' if result.resigned else ''}"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
