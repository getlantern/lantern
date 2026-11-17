#!/usr/bin/env python3
"""Check compiler hardening on the native code we build for Android.

MASA 1.6.3.1 (engineering#3975) wants stack canaries and full RELRO. This checks
libgojni.so in AARs and APKs, and that libc++_shared.so is no longer packaged.
libapp.so is Flutter's AOT snapshot: no C code and no dynamic relocations, so
neither applies to it.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import struct
import sys
import zipfile

PT_GNU_RELRO = 0x6474E552
SHT_DYNSYM, SHT_DYNAMIC = 11, 6
DT_NEEDED, DT_BIND_NOW, DT_FLAGS, DT_FLAGS_1 = 1, 24, 30, 0x6FFFFFFB
DF_BIND_NOW, DF_1_NOW = 0x8, 0x1


class VerificationError(ValueError):
    pass


def cstr(data: bytes, offset: int) -> str:
    return data[offset:data.index(b"\0", offset)].decode()


def inspect_elf(data: bytes) -> dict:
    if data[:4] != b"\x7fELF" or data[5] != 1:
        raise VerificationError("not a little-endian ELF file")
    is64 = data[4] == 2
    if is64:
        phoff, shoff = struct.unpack_from("<QQ", data, 32)
        phentsize, phnum, shentsize, shnum = struct.unpack_from("<HHHH", data, 54)
    else:
        phoff, shoff = struct.unpack_from("<II", data, 28)
        phentsize, phnum, shentsize, shnum = struct.unpack_from("<HHHH", data, 42)

    # An empty GNU_RELRO segment protects nothing.
    memsz_at, memsz_fmt = (40, "<Q") if is64 else (20, "<I")
    relro = any(
        struct.unpack_from("<I", data, base)[0] == PT_GNU_RELRO and struct.unpack_from(memsz_fmt, data, base + memsz_at)[0] > 0
        for base in (phoff + i * phentsize for i in range(phnum))
    )

    sections = []
    for i in range(shnum):
        base = shoff + i * shentsize
        if is64:
            _, kind, _, _, offset, size, link, _, _, entsize = struct.unpack_from("<IIQQQQIIQQ", data, base)
        else:
            _, kind, _, _, offset, size, link, _, _, entsize = struct.unpack_from("<IIIIIIIIII", data, base)
        sections.append((kind, offset, size, link, entsize))

    def strtab(link: int) -> bytes:
        _, offset, size, _, _ = sections[link]
        return data[offset:offset + size]

    symbols, needed, bind_now = set(), set(), False
    for kind, offset, size, link, entsize in sections:
        if kind == SHT_DYNSYM and entsize:
            names = strtab(link)
            for base in range(offset, offset + size, entsize):
                symbols.add(cstr(names, struct.unpack_from("<I", data, base)[0]))
        elif kind == SHT_DYNAMIC and entsize:
            names = strtab(link)
            for base in range(offset, offset + size, entsize):
                tag, value = struct.unpack_from("<qQ" if is64 else "<iI", data, base)
                if tag == DT_NEEDED:
                    needed.add(cstr(names, value))
                elif (tag == DT_BIND_NOW or (tag == DT_FLAGS and value & DF_BIND_NOW)
                      or (tag == DT_FLAGS_1 and value & DF_1_NOW)):
                    bind_now = True
    return {"canary": "__stack_chk_fail" in symbols, "relro": relro, "bind_now": bind_now, "needed": needed}


def verify_artifact(path: Path) -> int:
    checked = 0
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            library = name.rsplit("/", 1)[-1]
            if library == "libc++_shared.so":
                raise VerificationError(f"{path}: {name} is packaged; link libc++ statically into libgojni.so")
            if library != "libgojni.so":
                continue
            info = inspect_elf(archive.read(name))
            problems = [label for label, ok in (
                ("no stack canary", info["canary"]),
                ("no GNU_RELRO segment", info["relro"]),
                ("no BIND_NOW (partial RELRO)", info["bind_now"]),
                ("links libc++_shared.so", "libc++_shared.so" not in info["needed"]),
            ) if not ok]
            if problems:
                raise VerificationError(f"{path}: {name}: {', '.join(problems)}")
            checked += 1
    if not checked:
        raise VerificationError(f"{path}: no libgojni.so found")
    return checked


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", nargs="+", type=Path, help="AAR, APK or AAB files")
    args = parser.parse_args()
    try:
        for path in args.artifacts:
            print(f"Verified hardening in {path}: {verify_artifact(path)} libgojni.so")
    except (OSError, zipfile.BadZipFile, VerificationError, struct.error) as error:
        print(f"Android hardening verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
