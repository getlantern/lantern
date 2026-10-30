#!/usr/bin/env python3
"""Verify native hardening in release Android AAR, APK and AAB ZIP artifacts.

Uses only the Python standard library. The report preserves scanner evidence,
including absent canaries/RELRO on recognized Dart AOT snapshots. This verifies
build artifacts, not runtime safety or the Play-distributed application.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

from verify_android_abis import ELF_ABIS, VerificationError, native_entry, parse_abis


MAX_ELF_BYTES = 256 * 1024 * 1024
DART_SYMBOLS = frozenset({
    "_kDartVmSnapshotInstructions", "_kDartIsolateSnapshotInstructions",
    "_kDartVmSnapshotData", "_kDartIsolateSnapshotData", "_kDartSnapshotBuildId",
})
DART_REFERENCE = "https://docs.flutter.dev/reference/security-false-positives"
# Dart's direct ELF emitter needs only symbol/string/hash tables. A new dynamic
# feature must be reviewed before receiving the exception (including RELR and
# Android packed relocations, which a conventional REL/RELA check can miss).
DART_DYNAMIC_TAGS = {0, 4, 5, 6, 10, 11, 0x6FFFFEF5}
RELOCATION_SECTIONS = {4, 9, 19, 0x60000001, 0x60000002, 0x6FFFFF00}


class Elf:
    """Read the load/dynamic metadata and dynamic symbols of Android ELF files."""

    def __init__(self, data: bytes, abi: str):
        self.data = data
        if len(data) < 16 or data[:4] != b"\x7fELF" or data[5:7] != b"\x01\x01":
            raise VerificationError("not a little-endian ELF with version 1")
        self.bits = {1: 32, 2: 64}.get(data[4])
        if self.bits is None:
            raise VerificationError("unsupported ELF class")
        header_format = "16sHHIIIIIHHHHHH" if self.bits == 32 else "16sHHIQQQIHHHHHH"
        header = self.unpack(header_format, 0)
        (_, self.type, self.machine, version, _, phoff, shoff, _, ehsize,
         phentsize, phnum, shentsize, shnum, shstrndx) = header
        if abi not in ELF_ABIS or (data[4], self.machine) != ELF_ABIS[abi]:
            raise VerificationError(f"ELF class/machine {(data[4], self.machine)} does not match {abi}")
        if version != 1 or ehsize != struct.calcsize("<" + header_format):
            raise VerificationError("invalid ELF header version or size")
        if not phnum or not shnum or phnum == 0xFFFF or shstrndx >= shnum:
            raise VerificationError("missing or unsupported extended ELF tables")

        phformat = "IIIIIIII" if self.bits == 32 else "IIQQQQQQ"
        self.segments = []
        for values in self.table(phformat, phoff, phentsize, phnum):
            if self.bits == 32:
                kind, offset, address, _, size, memory, flags, _ = values
            else:
                kind, flags, offset, address, _, size, memory, _ = values
            self.range(offset, size)
            if kind == 1 and size > memory:
                raise VerificationError("LOAD file size exceeds memory size")
            self.segments.append((kind, flags, offset, address, size, memory))
        if not any(segment[0] == 1 for segment in self.segments):
            raise VerificationError("missing LOAD segment")

        shformat = "IIIIIIIIII" if self.bits == 32 else "IIQQQQIIQQ"
        self.sections = list(self.table(shformat, shoff, shentsize, shnum))
        for section in self.sections:
            if section[1] != 8:  # SHT_NOBITS has no file contents.
                self.range(section[4], section[5])
        names = self.sections[shstrndx]
        if names[1] != 3:
            raise VerificationError("section names do not reference a string table")
        self.section_names = [self.string(names, section[0]) for section in self.sections]

        dynamic = [segment for segment in self.segments if segment[0] == 2]
        if len(dynamic) != 1:
            raise VerificationError("expected one DYNAMIC segment")
        _, _, offset, address, size, _ = dynamic[0]
        if self.loaded_offset(address, size) != offset:
            raise VerificationError("DYNAMIC segment does not match its LOAD mapping")
        dyformat = "iI" if self.bits == 32 else "qQ"
        dysize = struct.calcsize("<" + dyformat)
        if not size or size % dysize:
            raise VerificationError("invalid dynamic table size")
        self.dynamic: dict[int, list[int]] = {}
        terminated = False
        for tag, value in self.table(dyformat, offset, dysize, size // dysize):
            if terminated:
                if tag or value:
                    raise VerificationError("nonzero dynamic entry after DT_NULL")
                continue
            self.dynamic.setdefault(tag, []).append(value)
            terminated = tag == 0
        if not terminated:
            raise VerificationError("unterminated dynamic table")
        for tag in (24, 30, 0x6FFFFFFB):
            if len(self.dynamic.get(tag, [])) > 1:
                raise VerificationError(f"duplicate immediate-binding dynamic tag {tag}")

        dynsyms = [section for section in self.sections if section[1] == 11]
        if len(dynsyms) != 1:
            raise VerificationError("expected one dynamic symbol table")
        symbols = dynsyms[0]
        if symbols[6] >= shnum or self.sections[symbols[6]][1] != 3:
            raise VerificationError("invalid dynamic symbol string table")
        strings = self.sections[symbols[6]]
        syformat = "IIIBBH" if self.bits == 32 else "IBBHQQ"
        sysize = struct.calcsize("<" + syformat)
        if not symbols[5] or symbols[5] % sysize or symbols[9] != sysize:
            raise VerificationError("invalid dynamic symbol table size")
        if (self.single_tag(6) != symbols[3] or self.single_tag(11) != sysize
                or self.single_tag(5) != strings[3] or self.single_tag(10) != strings[5]
                or self.loaded_offset(symbols[3], symbols[5]) != symbols[4]
                or self.loaded_offset(strings[3], strings[5]) != strings[4]):
            raise VerificationError("dynamic symbols/strings do not match loader metadata")
        self.symbols = []
        for index, values in enumerate(self.table(syformat, symbols[4], sysize, symbols[5] // sysize)):
            if self.bits == 32:
                name, _, _, info, other, section_index = values
            else:
                name, info, other, section_index, _, _ = values
            if index == 0:
                if any(values):
                    raise VerificationError("invalid null dynamic symbol")
                continue
            if section_index == 0xFFFF or (shnum <= section_index < 0xFF00):
                raise VerificationError("invalid dynamic symbol section index")
            self.symbols.append((self.string(strings, name), info, other, section_index))

    def range(self, offset: int, size: int) -> None:
        if offset < 0 or size < 0 or offset > len(self.data) or size > len(self.data) - offset:
            raise VerificationError("truncated or out-of-bounds ELF data")

    def unpack(self, format_: str, offset: int) -> tuple:
        self.range(offset, struct.calcsize("<" + format_))
        return struct.unpack_from("<" + format_, self.data, offset)

    def table(self, format_: str, offset: int, stride: int, count: int):
        if stride != struct.calcsize("<" + format_):
            raise VerificationError("invalid ELF table entry size")
        self.range(offset, stride * count)
        for index in range(count):
            yield self.unpack(format_, offset + stride * index)

    def string(self, section: tuple, index: int) -> str:
        if index >= section[5]:
            raise VerificationError("ELF string offset outside its table")
        start = section[4] + index
        end = self.data.find(b"\0", start, section[4] + section[5])
        if end == -1:
            raise VerificationError("unterminated ELF string")
        try:
            return self.data[start:end].decode("utf-8")
        except UnicodeDecodeError as error:
            raise VerificationError("invalid ELF symbol/section name") from error

    def loaded_offset(self, address: int, size: int) -> int:
        matches = [offset + address - base for kind, _, offset, base, length, _ in self.segments
                   if kind == 1 and base <= address and size <= length - (address - base)]
        if len(matches) != 1:
            raise VerificationError("dynamic data has no unique file-backed LOAD mapping")
        return matches[0]

    def single_tag(self, tag: int) -> int:
        values = self.dynamic.get(tag, [])
        if len(values) != 1:
            raise VerificationError(f"missing or duplicate dynamic tag {tag}")
        return values[0]

    def is_dart_snapshot(self) -> bool:
        return (
            len(self.symbols) == len(DART_SYMBOLS)
            and {symbol[0] for symbol in self.symbols} == DART_SYMBOLS
            and all(info == 0x11 and other == 0 and 0 < index < len(self.sections)
                    for _, info, other, index in self.symbols)
            and self.dynamic.keys() <= DART_DYNAMIC_TAGS
            and not any(section[1] in RELOCATION_SECTIONS for section in self.sections)
            and not any(name.startswith((".got", ".plt", ".rel", ".android.rel", ".igot", ".iplt"))
                        for name in self.section_names)
        )


def inspect_elf(data: bytes, abi: str, name: str) -> dict:
    elf = Elf(data, abi)
    stack = [segment for segment in elf.segments if segment[0] == 0x6474E551]
    relro = any(segment[0] == 0x6474E552 and segment[5] > 0 for segment in elf.segments)
    now = (24 in elf.dynamic or any(value & 8 for value in elf.dynamic.get(30, []))
           or any(value & 1 for value in elf.dynamic.get(0x6FFFFFFB, [])))
    raw = {
        "pic": elf.type == 3,
        "nx": len(stack) == 1 and not stack[0][1] & 1,
        "wx_load": any(kind == 1 and flags & 3 == 3 for kind, flags, *_ in elf.segments),
        "gnu_relro": relro,
        "bind_now": now,
        "relro": "full" if relro and now else "partial" if relro else "none",
        "canary": any(symbol == "__stack_chk_fail" and index == 0
                      for symbol, _, _, index in elf.symbols),
    }
    dart = name == "libapp.so" and elf.is_dart_snapshot()
    exceptions = []
    if dart:
        exceptions = [{
            "checks": ["relro", "canary"], "classification": "not_applicable",
            "reason": "Dart AOT snapshot: exact snapshot OBJECT exports, no imports, GOT/PLT or relocations",
            "reference": DART_REFERENCE,
        }]
    errors = []
    if not raw["pic"]:
        errors.append("expected ET_DYN (position-independent shared object)")
    if not raw["nx"]:
        errors.append("missing or executable GNU_STACK (NX required)")
    if raw["wx_load"]:
        errors.append("writable and executable LOAD segment")
    if raw["relro"] != "full" and not dart:
        errors.append("full RELRO requires GNU_RELRO and immediate binding")
    if name in {"libgojni.so", "libc++_shared.so", "libapp.so"} and not raw["canary"] and not dart:
        errors.append("missing undefined dynamic __stack_chk_fail symbol (stack canary evidence)")
    return {"elf_bits": elf.bits, "elf_machine": elf.machine, "raw": raw,
            "exceptions": exceptions, "errors": errors}


def verify_artifact(path: Path, kind: str, expected: set[str]) -> dict:
    result = {"path": str(path), "kind": kind, "expected_abis": sorted(expected),
              "libraries": [], "errors": []}
    inventory: dict[str, set[str]] = {}
    try:
        with zipfile.ZipFile(path) as archive:
            for entry in archive.infolist():
                native = native_entry(entry.filename, kind)
                if native is None:
                    continue
                abi, module_name = native
                name = module_name.rsplit("/", 1)[-1]
                names = inventory.setdefault(abi, set())
                if module_name in names:
                    result["errors"].append(f"duplicate native library: {entry.filename}")
                names.add(module_name)
                library = {"entry": entry.filename, "abi": abi, "name": name,
                           "sha256": None, "raw": {}, "exceptions": [], "errors": []}
                result["libraries"].append(library)
                try:
                    if entry.file_size > MAX_ELF_BYTES:
                        raise VerificationError("native library exceeds 256 MiB inspection limit")
                    data = archive.read(entry)
                    library["sha256"] = hashlib.sha256(data).hexdigest()
                    library.update(inspect_elf(data, abi, name))
                except (VerificationError, OSError, RuntimeError, zipfile.BadZipFile) as error:
                    library["errors"].append(str(error))
                if abi not in expected:
                    library["errors"].append(f"unexpected ABI {abi}")
                result["errors"].extend(f"{entry.filename}: {error}" for error in library["errors"])
    except (OSError, zipfile.BadZipFile) as error:
        result["errors"].append(str(error))
    missing_abis = expected - inventory.keys()
    if missing_abis:
        result["errors"].append(f"missing ABIs: {', '.join(sorted(missing_abis))}")
    required = {"libgojni.so"}
    if kind != "aar":
        required.update({"libapp.so", "libc++_shared.so", "libflutter.so"})
    if kind == "aab":
        required = {f"base/{name}" for name in required}
    for abi in sorted(expected):
        missing = required - inventory.get(abi, set())
        if missing:
            result["errors"].append(f"{abi}: missing required libraries: {', '.join(sorted(missing))}")
    result["passed"] = not result["errors"]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-abis", default=",".join(ELF_ABIS))
    parser.add_argument("--app-abis", help="APK/AAB ABI subset for per-ABI release APKs")
    for kind in ("aar", "apk", "aab"):
        parser.add_argument(f"--{kind}", action="append", type=Path, default=[])
    parser.add_argument("--report", type=Path, help="Write JSON evidence, including when verification fails")
    args = parser.parse_args()
    if not (args.aar or args.apk or args.aab):
        parser.error("provide at least one --aar, --apk or --aab")
    try:
        expected = parse_abis(args.expected_abis)
        app_expected = parse_abis(args.app_abis) if args.app_abis else expected
        if not app_expected <= expected:
            raise VerificationError("--app-abis must be a subset of --expected-abis")
    except VerificationError as error:
        parser.error(str(error))
    artifacts = [verify_artifact(path, kind, expected if kind == "aar" else app_expected)
                 for kind in ("aar", "apk", "aab") for path in getattr(args, kind)]
    report = {"passed": all(artifact["passed"] for artifact in artifacts), "artifacts": artifacts}
    if args.report:
        try:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n")
        except OSError as error:
            print(f"Cannot write hardening report: {error}", file=sys.stderr)
            return 1
    for artifact in artifacts:
        if artifact["passed"]:
            print(f"Verified native hardening: {artifact['path']} ({len(artifact['libraries'])} libraries)")
        else:
            for error in artifact["errors"]:
                print(f"Android hardening verification failed: {artifact['path']}: {error}", file=sys.stderr)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
