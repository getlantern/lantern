from __future__ import annotations

from pathlib import Path
import struct
import tempfile
import unittest
import zipfile

from verify_android_hardening import (
    DF_BIND_NOW, DT_BIND_NOW, DT_FLAGS, DT_NEEDED, PT_GNU_RELRO, SHT_DYNAMIC, SHT_DYNSYM,
    VerificationError, inspect_elf, verify_artifact,
)


def elf64(*, symbols=("__stack_chk_fail",), needed=("libc.so",), relro=True, relro_size=0x1000,
          bind_now="flags") -> bytes:
    """A minimal ELF64 shared object with just the bits the checker reads."""
    names = b"\0"
    offsets = {}
    for name in (*symbols, *needed):
        offsets[name] = len(names)
        names += name.encode() + b"\0"
    dynsym = bytes(24) + b"".join(struct.pack("<IBBHQQ", offsets[s], 0x12, 0, 0, 0, 0) for s in symbols)
    entries = [(DT_NEEDED, offsets[n]) for n in needed]
    if bind_now == "flags":
        entries.append((DT_FLAGS, DF_BIND_NOW))
    elif bind_now == "tag":
        entries.append((DT_BIND_NOW, 0))
    dynamic = b"".join(struct.pack("<qQ", tag, value) for tag, value in (*entries, (0, 0)))

    phoff = 64
    phdr = struct.pack("<IIQQQQQQ", PT_GNU_RELRO if relro else 1, 4, 0, 0, 0, relro_size, relro_size, 1)
    strtab_off = phoff + len(phdr)
    dynsym_off = strtab_off + len(names)
    dynamic_off = dynsym_off + len(dynsym)
    shoff = dynamic_off + len(dynamic)
    sections = [
        struct.pack("<IIQQQQIIQQ", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        struct.pack("<IIQQQQIIQQ", 0, 3, 0, 0, strtab_off, len(names), 0, 0, 1, 0),
        struct.pack("<IIQQQQIIQQ", 0, SHT_DYNSYM, 0, 0, dynsym_off, len(dynsym), 1, 1, 8, 24),
        struct.pack("<IIQQQQIIQQ", 0, SHT_DYNAMIC, 0, 0, dynamic_off, len(dynamic), 1, 0, 8, 16),
    ]
    header = b"\x7fELF" + bytes([2, 1, 1]) + bytes(9)
    header += struct.pack("<HHIQQQIHHHHHH", 3, 183, 1, 0, phoff, shoff, 0, 64, 56, 1, 64, len(sections), 0)
    return header + phdr + names + dynsym + dynamic + b"".join(sections)


class InspectElfTest(unittest.TestCase):
    def test_reads_canary_relro_and_needed(self) -> None:
        info = inspect_elf(elf64(needed=("libc.so", "liblog.so")))
        self.assertEqual(info, {"canary": True, "relro": True, "bind_now": True, "needed": {"libc.so", "liblog.so"}})

    def test_missing_features(self) -> None:
        info = inspect_elf(elf64(symbols=("malloc",), relro=False, bind_now=None))
        self.assertFalse(info["canary"])
        self.assertFalse(info["relro"])
        self.assertFalse(info["bind_now"])

    def test_dt_bind_now_tag_counts_as_bind_now(self) -> None:
        self.assertTrue(inspect_elf(elf64(bind_now="tag"))["bind_now"])

    def test_empty_relro_segment_does_not_count(self) -> None:
        self.assertFalse(inspect_elf(elf64(relro_size=0))["relro"])


class VerifyArtifactTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)

    def artifact(self, files: dict[str, bytes]) -> Path:
        path = self.directory / "app.apk"
        with zipfile.ZipFile(path, "w") as archive:
            for name, data in files.items():
                archive.writestr(name, data)
        return path

    def test_hardened_libgojni_passes(self) -> None:
        path = self.artifact({"lib/arm64-v8a/libgojni.so": elf64(), "lib/arm64-v8a/libapp.so": b""})
        self.assertEqual(verify_artifact(path), 1)

    def test_rejects_each_regression(self) -> None:
        cases = {
            "no stack canary": elf64(symbols=("malloc",)),
            "no GNU_RELRO": elf64(relro=False),
            "no BIND_NOW": elf64(bind_now=None),
            "no GNU_RELRO segment": elf64(relro_size=0),
            "links libc\\+\\+_shared.so": elf64(needed=("libc.so", "libc++_shared.so")),
        }
        for message, library in cases.items():
            with self.subTest(message), self.assertRaisesRegex(VerificationError, message):
                verify_artifact(self.artifact({"jni/arm64-v8a/libgojni.so": library}))

    def test_rejects_packaged_libcxx_shared(self) -> None:
        path = self.artifact({"lib/arm64-v8a/libgojni.so": elf64(), "lib/arm64-v8a/libc++_shared.so": b""})
        with self.assertRaisesRegex(VerificationError, "libc\\+\\+_shared.so is packaged"):
            verify_artifact(path)

    def test_requires_libgojni(self) -> None:
        with self.assertRaisesRegex(VerificationError, "no libgojni.so"):
            verify_artifact(self.artifact({"lib/arm64-v8a/libflutter.so": elf64()}))


if __name__ == "__main__":
    unittest.main()
