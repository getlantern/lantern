from __future__ import annotations

import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile

from verify_android_hardening import (
    DART_SYMBOLS, ELF_ABIS, Elf, VerificationError, inspect_elf, verify_artifact,
)


def elf(abi: str = "arm64-v8a", *, dart: bool = False, canary: bool | None = None,
        relro: bool | None = None, now: bool | None = None, nx: bool = True,
        stack: bool = True, wx: bool = False, object_type: int = 3,
        now_tag: int = 30, extra_tags: tuple = (), extra_sections: tuple = (),
        symbols: list | None = None, defined_canary: bool = False) -> bytes:
    """Small loadable ELF fixtures with real linked dynamic/string/symbol tables."""
    elf_class, machine = ELF_ABIS[abi]
    is32 = elf_class == 1
    base = 0x10000
    header_size, ph_size, sh_size, sym_size, dy_size = (52, 32, 40, 16, 8) if is32 else (64, 56, 64, 24, 16)
    canary = not dart if canary is None else canary
    relro = not dart if relro is None else relro
    now = not dart if now is None else now
    if symbols is None:
        symbols = [(name, 0x11, 4) for name in sorted(DART_SYMBOLS)] if dart else [("entry", 0x12, 4)]
    symbols = list(symbols)
    if canary:
        symbols.append(("__stack_chk_fail", 0x12, 4 if defined_canary else 0))
    strings = bytearray(b"\0")
    symbol_names = []
    for name, _, _ in symbols:
        symbol_names.append(len(strings))
        strings.extend(name.encode() + b"\0")
    section_names = ["", ".dynstr", ".dynsym", ".dynamic", ".rodata"]
    section_names += [name for name, _ in extra_sections] + [".shstrtab"]
    section_strings = bytearray(b"\0")
    name_offsets = [0]
    for name in section_names[1:]:
        name_offsets.append(len(section_strings))
        section_strings.extend(name.encode() + b"\0")
    ph_count = 2 + stack + relro
    output = bytearray(header_size + ph_size * ph_count)

    def append(content: bytes) -> int:
        output.extend(b"\0" * (-len(output) % 8))
        offset = len(output)
        output.extend(content)
        return offset

    strings_offset = append(strings)
    symbols_offset = append(bytes(sym_size * (len(symbols) + 1)))
    tags = [(5, base + strings_offset), (10, len(strings)),
            (6, base + symbols_offset), (11, sym_size)]
    if now:
        tags.append((now_tag, {24: 0, 30: 8, 0x6FFFFFFB: 1}[now_tag]))
    tags += list(extra_tags) + [(0, 0)]
    dynamic = b"".join(struct.pack("<iI" if is32 else "<qQ", *pair) for pair in tags)
    dynamic_offset = append(dynamic)
    rodata_offset = append(b"\0")
    extra_offsets = [append(b"\0" * 8) for _ in extra_sections]
    shstrings_offset = append(section_strings)
    for index, ((_, info, section), name_offset) in enumerate(zip(symbols, symbol_names), 1):
        address = base + rodata_offset if section else 0
        if is32:
            values = (name_offset, address, 1 if section else 0, info, 0, section)
        else:
            values = (name_offset, info, 0, section, address, 1 if section else 0)
        struct.pack_into("<IIIBBH" if is32 else "<IBBHQQ", output, symbols_offset + index * sym_size, *values)
    sections = [
        (0,) * 10,
        (name_offsets[1], 3, 2, base + strings_offset, strings_offset, len(strings), 0, 0, 1, 0),
        (name_offsets[2], 11, 2, base + symbols_offset, symbols_offset, sym_size * (len(symbols) + 1), 1, 1, 8, sym_size),
        (name_offsets[3], 6, 3, base + dynamic_offset, dynamic_offset, len(dynamic), 1, 0, 8, dy_size),
        (name_offsets[4], 1, 2, base + rodata_offset, rodata_offset, 1, 0, 0, 1, 0),
    ]
    for index, ((_, kind), offset) in enumerate(zip(extra_sections, extra_offsets), 5):
        sections.append((name_offsets[index], kind, 2, base + offset, offset, 8, 0, 0, 8, 0))
    sections.append((name_offsets[-1], 3, 0, 0, shstrings_offset, len(section_strings), 0, 0, 1, 0))
    sh_offset = append(b"".join(struct.pack("<IIIIIIIIII" if is32 else "<IIQQQQIIQQ", *section)
                              for section in sections))
    ident = b"\x7fELF" + bytes([elf_class, 1, 1]) + bytes(9)
    header = (ident, object_type, machine, 1, 0, header_size, sh_offset, 0,
              header_size, ph_size, ph_count, sh_size, len(sections), len(sections) - 1)
    struct.pack_into("<16sHHIIIIIHHHHHH" if is32 else "<16sHHIQQQIHHHHHH", output, 0, *header)
    segments = [(1, 7 if wx else 4, 0, base, len(output), len(output)),
                (2, 6, dynamic_offset, base + dynamic_offset, len(dynamic), len(dynamic))]
    if stack:
        segments.append((0x6474E551, 6 if nx else 7, 0, 0, 0, 0))
    if relro:
        segments.append((0x6474E552, 4, dynamic_offset, base + dynamic_offset, len(dynamic), len(dynamic)))
    for index, (kind, flags, offset, address, size, memory) in enumerate(segments):
        values = ((kind, offset, address, address, size, memory, flags, 8) if is32
                  else (kind, flags, offset, address, address, size, memory, 8))
        struct.pack_into("<IIIIIIII" if is32 else "<IIQQQQQQ", output, header_size + index * ph_size, *values)
    return bytes(output)


class ElfHardeningTest(unittest.TestCase):
    def test_elf32_and_elf64_native_evidence(self) -> None:
        for abi in ELF_ABIS:
            with self.subTest(abi=abi):
                result = inspect_elf(elf(abi), abi, "libgojni.so")
                self.assertEqual(result["errors"], [])
                self.assertEqual(result["raw"], {
                    "pic": True, "nx": True, "wx_load": False, "gnu_relro": True,
                    "bind_now": True, "relro": "full", "canary": True,
                })

    def test_canary_must_be_an_import_in_each_target_library(self) -> None:
        for abi in ELF_ABIS:
            for name in ("libgojni.so", "libc++_shared.so", "libapp.so"):
                for options in ({"canary": False}, {"defined_canary": True}):
                    with self.subTest(abi=abi, name=name, options=options):
                        result = inspect_elf(elf(abi, **options), abi, name)
                        self.assertFalse(result["raw"]["canary"])
                        self.assertIn("__stack_chk_fail", " ".join(result["errors"]))
        other = inspect_elf(elf(canary=False), "arm64-v8a", "libflutter.so")
        self.assertFalse(other["raw"]["canary"])
        self.assertEqual(other["errors"], [])

    def test_native_hardening_failures(self) -> None:
        cases = [({"relro": False}, "full RELRO"), ({"now": False}, "full RELRO"),
                 ({"nx": False}, "GNU_STACK"), ({"stack": False}, "GNU_STACK"),
                 ({"wx": True}, "writable and executable"), ({"object_type": 2}, "ET_DYN")]
        for abi in ELF_ABIS:
            for options, error in cases:
                with self.subTest(abi=abi, options=options):
                    self.assertIn(error, " ".join(inspect_elf(elf(abi, **options), abi, "libgojni.so")["errors"]))

    def test_all_standard_immediate_binding_encodings(self) -> None:
        for abi in ELF_ABIS:
            for tag in (24, 30, 0x6FFFFFFB):
                with self.subTest(abi=abi, tag=tag):
                    self.assertEqual(inspect_elf(elf(abi, now_tag=tag), abi, "libgojni.so")["errors"], [])

    def test_dart_exception_preserves_raw_failures(self) -> None:
        for abi in ELF_ABIS:
            with self.subTest(abi=abi):
                result = inspect_elf(elf(abi, dart=True), abi, "libapp.so")
                self.assertEqual(result["errors"], [])
                self.assertEqual(result["raw"]["relro"], "none")
                self.assertFalse(result["raw"]["canary"])
                self.assertEqual(result["exceptions"][0]["classification"], "not_applicable")
                renamed = inspect_elf(elf(abi, dart=True), abi, "libother.so")
                self.assertEqual(renamed["exceptions"], [])
                self.assertIn("full RELRO", " ".join(renamed["errors"]))

    def test_dart_signature_rejects_imports_wrong_exports_and_linker_features(self) -> None:
        expected = [(name, 0x11, 4) for name in sorted(DART_SYMBOLS)]
        cases = [{"canary": True}, {"symbols": expected[:-1]},
                 {"symbols": expected + [("extra", 0x11, 4)]},
                 {"symbols": [(name, 0x12, index) for name, _, index in expected]},
                 {"symbols": [(name, info, 0) for name, info, _ in expected]},
                 {"symbols": [(name, 0x01, index) for name, _, index in expected]}]
        cases += [{"extra_tags": ((tag, 0),)} for tag in (1, 3, 7, 17, 23, 36, 0x6000000F, 0x60000011)]
        cases += [{"extra_sections": ((name, kind),)} for name, kind in
                  ((".got", 1), (".plt", 1), (".rel.dyn", 9), (".rela.dyn", 4),
                   (".relr.dyn", 19), (".android.rel.dyn", 0x60000001), (".hidden", 9))]
        for abi in ELF_ABIS:
            for options in cases:
                with self.subTest(abi=abi, options=options):
                    result = inspect_elf(elf(abi, dart=True, **options), abi, "libapp.so")
                    self.assertEqual(result["exceptions"], [])
                    self.assertIn("full RELRO", " ".join(result["errors"]))

    def test_dart_is_still_subject_to_pic_nx_and_wx_checks(self) -> None:
        for options in ({"object_type": 2}, {"nx": False}, {"wx": True}):
            with self.subTest(options=options):
                result = inspect_elf(elf(dart=True, **options), "arm64-v8a", "libapp.so")
                self.assertTrue(result["exceptions"])
                self.assertTrue(result["errors"])

    def test_full_relro_does_not_exempt_unrecognized_libapp_from_canaries(self) -> None:
        result = inspect_elf(elf(canary=False), "arm64-v8a", "libapp.so")
        self.assertEqual(result["raw"]["relro"], "full")
        self.assertEqual(result["exceptions"], [])
        self.assertIn("__stack_chk_fail", " ".join(result["errors"]))

    def test_truncated_and_malformed_elf_fail_closed(self) -> None:
        for abi in ELF_ABIS:
            valid = elf(abi)
            for length in (0, 15, 30, 51, len(valid) - 1):
                with self.subTest(abi=abi, length=length), self.assertRaises(VerificationError):
                    inspect_elf(valid[:length], abi, "libgojni.so")
            for byte_offset, format_, value in ((5, "B", 2), (18, "H", 62),
                                                (32 if abi == "armeabi-v7a" else 40,
                                                 "I" if abi == "armeabi-v7a" else "Q", len(valid) + 1024)):
                broken = bytearray(valid)
                struct.pack_into("<" + format_, broken, byte_offset, value)
                with self.subTest(abi=abi, offset=byte_offset), self.assertRaises(VerificationError):
                    inspect_elf(bytes(broken), abi, "libgojni.so")
            with self.assertRaisesRegex(VerificationError, "duplicate dynamic tag"):
                inspect_elf(elf(abi, extra_tags=((6, 1),)), abi, "libgojni.so")
            with self.assertRaisesRegex(VerificationError, "duplicate immediate-binding"):
                inspect_elf(elf(abi, extra_tags=((30, 0),)), abi, "libgojni.so")

    def test_symbol_metadata_must_agree_with_loader(self) -> None:
        for abi in ELF_ABIS:
            valid = elf(abi)
            parsed = Elf(valid, abi)
            dynsym = next(section for section in parsed.sections if section[1] == 11)
            broken = bytearray(valid)
            # Keep the dynamic symbol table intact but corrupt the imported
            # canary's name offset beyond the actual string table.
            struct.pack_into("<I", broken, dynsym[4] + 2 * dynsym[9], len(valid))
            with self.subTest(abi=abi), self.assertRaisesRegex(VerificationError, "string offset"):
                inspect_elf(bytes(broken), abi, "libgojni.so")
            broken = bytearray(valid)
            dynamic = next(segment for segment in parsed.segments if segment[0] == 2)
            # DT_STRTAB must map to the same loaded bytes as .dynsym's link.
            struct.pack_into("<I" if abi == "armeabi-v7a" else "<Q", broken,
                             dynamic[2] + (4 if abi == "armeabi-v7a" else 8), 1)
            with self.subTest(abi=abi), self.assertRaisesRegex(VerificationError, "loader metadata"):
                inspect_elf(bytes(broken), abi, "libgojni.so")


class ArtifactHardeningTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    def artifact(self, kind: str, *, abis: tuple = tuple(ELF_ABIS), missing: str = "",
                 canary: bool = True, extra: dict | None = None) -> Path:
        path = self.directory / f"app-{len(list(self.directory.iterdir()))}.{kind}"
        prefix = {"aar": "jni", "apk": "lib", "aab": "base/lib"}[kind]
        names = ["libgojni.so", "libc++_shared.so"]
        if kind != "aar":
            names += ["libapp.so", "libflutter.so"]
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for abi in abis:
                for name in names:
                    if name == missing:
                        continue
                    data = elf(abi, dart=True) if name == "libapp.so" else elf(abi, canary=canary)
                    archive.writestr(f"{prefix}/{abi}/{name}", data)
            for name, data in (extra or {}).items():
                archive.writestr(name, data)
        return path

    def test_all_archive_layouts_and_hashes(self) -> None:
        for kind in ("aar", "apk", "aab"):
            path = self.artifact(kind)
            result = verify_artifact(path, kind, set(ELF_ABIS))
            with self.subTest(kind=kind):
                self.assertTrue(result["passed"], result["errors"])
                with zipfile.ZipFile(path) as archive:
                    for library in result["libraries"]:
                        self.assertEqual(library["sha256"], hashlib.sha256(archive.read(library["entry"])).hexdigest())

    def test_missing_abis_and_required_libraries_fail(self) -> None:
        for kind in ("aar", "apk", "aab"):
            with self.subTest(kind=kind):
                result = verify_artifact(self.artifact(kind, abis=("arm64-v8a",)), kind, set(ELF_ABIS))
                self.assertIn("missing ABIs: armeabi-v7a", result["errors"])
            for missing in (("libgojni.so",) if kind == "aar" else
                            ("libgojni.so", "libapp.so", "libc++_shared.so", "libflutter.so")):
                with self.subTest(kind=kind, missing=missing):
                    result = verify_artifact(self.artifact(kind, missing=missing), kind, set(ELF_ABIS))
                    self.assertFalse(result["passed"])
                    self.assertIn(missing, " ".join(result["errors"]))

    def test_feature_module_libraries_cannot_bypass_checks(self) -> None:
        path = self.artifact("aab", extra={"feature/lib/arm64-v8a/libgojni.so": elf(canary=False)})
        result = verify_artifact(path, "aab", set(ELF_ABIS))
        self.assertFalse(result["passed"])
        self.assertIn("feature/lib/arm64-v8a/libgojni.so", " ".join(result["errors"]))

    def test_duplicate_unexpected_and_malformed_entries_fail(self) -> None:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            duplicate = self.artifact("aar", extra={"jni/arm64-v8a/libgojni.so": elf()})
        cases = [(duplicate, "duplicate native library"),
                 (self.artifact("aar", extra={"jni/x86/libgojni.so": elf()}), "unexpected ABI x86"),
                 (self.artifact("aar", extra={"jni/arm64-v8a/libbad.so": b"truncated"}), "not a little-endian ELF")]
        for path, error in cases:
            with self.subTest(error=error):
                result = verify_artifact(path, "aar", set(ELF_ABIS))
                self.assertFalse(result["passed"])
                self.assertIn(error, " ".join(result["errors"]))
        broken = self.directory / "broken.aar"
        broken.write_bytes(b"not a zip")
        self.assertFalse(verify_artifact(broken, "aar", set(ELF_ABIS))["passed"])

    def test_cli_writes_evidence_on_failure_and_supports_per_abi_apps(self) -> None:
        script = Path(__file__).with_name("verify_android_hardening.py")
        report = self.directory / "evidence/report.json"
        aar = self.artifact("aar")
        apk = self.artifact("apk", abis=("arm64-v8a",))
        args = [sys.executable, str(script), "--aar", str(aar), "--aar", str(aar),
                "--apk", str(apk), "--app-abis", "arm64-v8a", "--report", str(report)]
        result = subprocess.run(args, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        evidence = json.loads(report.read_text())
        self.assertTrue(evidence["passed"])
        self.assertEqual(len(evidence["artifacts"]), 3)
        bad = self.artifact("aar", canary=False)
        result = subprocess.run(args + ["--aar", str(bad)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 1)
        evidence = json.loads(report.read_text())
        self.assertFalse(evidence["passed"])
        library = evidence["artifacts"][2]["libraries"][0]
        self.assertFalse(library["raw"]["canary"])
        self.assertEqual(len(library["sha256"]), 64)
        self.assertIn("__stack_chk_fail", " ".join(library["errors"]))


if __name__ == "__main__":
    unittest.main()
