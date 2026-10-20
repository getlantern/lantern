#!/usr/bin/env python3
from pathlib import Path
import os
import struct
import sys
import tempfile
import unittest
import unittest.mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))

import sanitize_android_artifact


def _make_elf_with_section(section_name: str, section_data: bytes) -> bytes:
    """Build a minimal 64-bit little-endian ELF with one named section.

    Produces a byte-accurate ELF that the ``elf_sections`` parser can
    traverse, allowing tests to drive section-specific logic without
    depending on a real compiled binary.
    """
    ELF_HEADER_SIZE = 64
    SHDR_SIZE = 64  # 64-bit section header entry size

    # String table: \x00 | <section_name>\x00 | ".shstrtab\x00"
    strtab = bytearray(b"\x00")
    name_offset = len(strtab)
    strtab.extend(section_name.encode() + b"\x00")
    shstrtab_name_offset = len(strtab)
    strtab.extend(b".shstrtab\x00")
    strtab_bytes = bytes(strtab)

    # File layout: [ELF header][section data][shstrtab][section headers]
    section_data_offset = ELF_HEADER_SIZE
    shstrtab_data_offset = section_data_offset + len(section_data)
    shdrs_offset = shstrtab_data_offset + len(strtab_bytes)
    n_shdrs = 3       # null, named section, .shstrtab
    shstrtab_idx = 2  # index of the shstrtab section

    buf = bytearray()

    # ELF header — 64 bytes
    # e_ident[16]: magic + EI_CLASS=2(64-bit) + EI_DATA=1(LE) + EI_VERSION=1
    buf.extend(b"\x7fELF\x02\x01\x01\x00" + b"\x00" * 8)
    # e_type(H) e_machine(H) e_version(I)  [16..23]
    buf.extend(struct.pack("<HHI", 2, 0, 1))
    # e_entry(Q) e_phoff(Q) e_shoff(Q)     [24..47]
    buf.extend(struct.pack("<QQQ", 0, 0, shdrs_offset))
    # e_flags(I) e_ehsize(H) e_phentsize(H) [48..55]
    buf.extend(struct.pack("<IHH", 0, ELF_HEADER_SIZE, 0))
    # e_phnum(H) e_shentsize(H) e_shnum(H) e_shstrndx(H) [56..63]
    buf.extend(struct.pack("<HHHH", 0, SHDR_SIZE, n_shdrs, shstrtab_idx))

    assert len(buf) == ELF_HEADER_SIZE, f"header size mismatch: {len(buf)}"

    # Section content + string table
    buf.extend(section_data)
    buf.extend(strtab_bytes)

    assert len(buf) == shdrs_offset, "section headers must start here"

    # sh_name sh_type sh_flags sh_addr sh_offset sh_size sh_link sh_info sh_addralign sh_entsize
    shdr = "<IIQQQQIIQQ"

    # Null section header
    buf.extend(struct.pack(shdr, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    # Named section header
    buf.extend(struct.pack(shdr,
        name_offset,          # sh_name
        1,                    # sh_type = SHT_PROGBITS
        0, 0,                 # sh_flags, sh_addr
        section_data_offset,  # sh_offset
        len(section_data),    # sh_size
        0, 0, 1, 0,           # sh_link, sh_info, sh_addralign, sh_entsize
    ))
    # .shstrtab section header
    buf.extend(struct.pack(shdr,
        shstrtab_name_offset, # sh_name
        3,                    # sh_type = SHT_STRTAB
        0, 0,                 # sh_flags, sh_addr
        shstrtab_data_offset, # sh_offset
        len(strtab_bytes),    # sh_size
        0, 0, 1, 0,
    ))

    return bytes(buf)



def _isolated_gradle_project(root: Path) -> Path:
    app_dir = root / "android" / "app"
    app_dir.mkdir(parents=True)
    (root / "gradle-home").mkdir()
    return app_dir


def _signing_free_env(root: Path) -> dict[str, str]:
    env = {
        key: value
        for key, value in os.environ.items()
        if key not in sanitize_android_artifact.SIGNING_PROPERTIES
        and not key.startswith("ORG_GRADLE_PROJECT_")
    }
    env["GRADLE_USER_HOME"] = str(root / "gradle-home")
    return env

class SanitizeAndroidArtifactTest(unittest.TestCase):
    def test_strips_metadata_and_scrubs_native_text(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "app.aab"
            native = (
                b"\x00github.com/getlantern/radiance\x00"
                b"OverrideAndroidVPN\x00"
                b"DTLS-IN-STUN\x00"
                b"TunOptions\x00"
                b"Lantern\x00"
            )
            with zipfile.ZipFile(artifact, "w") as zf:
                zf.writestr("base/lib/arm64-v8a/libgojni.so", native)
                zf.writestr(
                    "BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map",
                    b"mapping",
                )

            result = sanitize_android_artifact.sanitize_zip(artifact)

            self.assertEqual(result.removed_metadata_entries, 1)
            # Only the brand strings are scrubbed (getlantern, Lantern); the
            # VPN/TUN native strings are intentionally preserved.
            self.assertGreaterEqual(result.scrubbed_native_strings, 2)
            with zipfile.ZipFile(artifact) as zf:
                self.assertNotIn(
                    "BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map",
                    zf.namelist(),
                )
                scrubbed = zf.read("base/lib/arm64-v8a/libgojni.so")
            self.assertEqual(len(native), len(scrubbed))
            self.assertNotIn(b"getlantern", scrubbed)
            self.assertNotIn(b"Lantern", scrubbed)
            # VPN/TUN native strings are intentionally NOT scrubbed: rewriting
            # them corrupts gomobile JNI class-name lookups (FindClass) and
            # crashes the Go runtime. novpn enforces their absence structurally
            # (Go build tags + manifest), not via native string scrubbing.
            self.assertIn(b"OverrideAndroidVPN", scrubbed)
            self.assertIn(b"DTLS-IN-STUN", scrubbed)
            self.assertIn(b"TunOptions", scrubbed)

    def test_does_not_scrub_non_native_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "app.apk"
            with zipfile.ZipFile(artifact, "w") as zf:
                zf.writestr("classes.dex", b"Lantern VPN")

            result = sanitize_android_artifact.sanitize_zip(artifact)

            self.assertEqual(result.scrubbed_native_strings, 0)
            with zipfile.ZipFile(artifact) as zf:
                self.assertEqual(zf.read("classes.dex"), b"Lantern VPN")

    def test_unchanged_artifact_keeps_original_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "app.apk"
            with zipfile.ZipFile(artifact, "w") as zf:
                zf.writestr("classes.dex", b"dex")
            # Trailing bytes stand in for data a zipfile repack would drop.
            with artifact.open("ab") as handle:
                handle.write(b"signing-block")
            original = artifact.read_bytes()

            with unittest.mock.patch.object(
                sanitize_android_artifact, "resign_android_artifact"
            ) as resign:
                result = sanitize_android_artifact.sanitize_zip(artifact, resign=True)

            self.assertFalse(result.resigned)
            resign.assert_not_called()
            self.assertEqual(artifact.read_bytes(), original)

    def test_go_buildinfo_section_is_zeroed_not_token_replaced(self) -> None:
        # Real .go.buildinfo sections contain structured module-graph lines such as
        # "dep\tgithub.com/getlantern/lantern\tv1.2.3".  Token replacement would
        # turn "getlantern" → "foundation" but leave the URL scaffold intact,
        # which is still informative.  The section must be fully zeroed instead.
        buildinfo_content = (
            b"go\t1.22.0\n"
            b"path\tgithub.com/getlantern/lantern\n"
            b"dep\tgithub.com/getlantern/flashlight\tv0.0.0-20240101\n"
        )
        elf_bytes = _make_elf_with_section(".go.buildinfo", buildinfo_content)

        scrubbed, replacements = sanitize_android_artifact.scrub_elf_text_sections(elf_bytes)

        # Must report work done (non-zero replacements so the caller doesn't fall back)
        self.assertGreater(replacements, 0)
        # Locate the section in the scrubbed output and verify it is all zeros
        sections = sanitize_android_artifact.elf_sections(elf_bytes)
        buildinfo_sections = [(o, s) for n, o, s in sections if n == ".go.buildinfo"]
        self.assertEqual(len(buildinfo_sections), 1)
        offset, size = buildinfo_sections[0]
        self.assertEqual(scrubbed[offset : offset + size], b"\x00" * size)
        # Must NOT contain any token-replaced strings (not the old replacement pattern)
        self.assertNotIn(b"foundation", scrubbed[offset : offset + size])
        # Tokens from other sections (there are none here) must be unaffected
        self.assertNotIn(b"getlantern", scrubbed)

    def test_does_not_fallback_to_whole_file_scrub_for_unparsed_elf(self) -> None:
        data = b"\x7fELF" + b"\x00" * 64 + b"JNI_SYMBOL_VpnService"

        scrubbed, replacements = sanitize_android_artifact.scrub_native_text(data)

        self.assertEqual(replacements, 0)
        self.assertEqual(scrubbed, data)

    def test_elf_no_replacements_does_not_fallback_to_full_file_scrub(self) -> None:
        elf_bytes = b"\x7fELFfakebinary"
        with unittest.mock.patch.object(
            sanitize_android_artifact,
            "scrub_elf_text_sections",
            return_value=(elf_bytes, 0),
        ) as scrub_elf, unittest.mock.patch.object(
            sanitize_android_artifact,
            "scrub_text_range",
        ) as scrub_range:
            scrubbed, replacements = sanitize_android_artifact.scrub_native_text(elf_bytes)

        self.assertEqual(scrubbed, elf_bytes)
        self.assertEqual(replacements, 0)
        scrub_elf.assert_called_once_with(elf_bytes)
        scrub_range.assert_not_called()

    def test_missing_artifact_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "missing.apk"

            with self.assertRaises(FileNotFoundError):
                sanitize_android_artifact.sanitize_zip(missing)

    def test_apk_resign_uses_env_passwords_not_argv(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / "app.apk"
            artifact.write_bytes(b"apk")
            signing = sanitize_android_artifact.SigningConfig(
                keystore=root / "release.keystore",
                store_password="store-secret",
                key_alias="release",
                key_password="key-secret",
            )

            with unittest.mock.patch.object(sanitize_android_artifact, "signing_config", return_value=signing), \
                    unittest.mock.patch.object(
                        sanitize_android_artifact,
                        "android_signing_tools",
                        return_value=(root / "zipalign", root / "apksigner"),
                    ), \
                    unittest.mock.patch.object(sanitize_android_artifact.subprocess, "run") as run, \
                    unittest.mock.patch.object(sanitize_android_artifact.shutil, "move"):
                sanitize_android_artifact.resign_android_artifact(artifact)

            self.assertEqual(run.call_count, 2)
            sign_args = run.call_args_list[1].args[0]
            sign_kwargs = run.call_args_list[1].kwargs
            self.assertIn("env:STEALTH_ANDROID_STORE_PASSWORD", sign_args)
            self.assertIn("env:STEALTH_ANDROID_KEY_PASSWORD", sign_args)
            self.assertNotIn("store-secret", sign_args)
            self.assertNotIn("key-secret", sign_args)
            self.assertEqual(sign_kwargs["env"]["STEALTH_ANDROID_STORE_PASSWORD"], "store-secret")
            self.assertEqual(sign_kwargs["env"]["STEALTH_ANDROID_KEY_PASSWORD"], "key-secret")

    def test_aab_resign_feeds_jarsigner_passwords_on_stdin(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            artifact = root / "app.aab"
            artifact.write_bytes(b"aab")
            signing = sanitize_android_artifact.SigningConfig(
                keystore=root / "release.keystore",
                store_password="store-secret",
                key_alias="release",
                key_password="key-secret",
            )

            with unittest.mock.patch.object(sanitize_android_artifact, "signing_config", return_value=signing), \
                    unittest.mock.patch.object(sanitize_android_artifact.subprocess, "run") as run, \
                    unittest.mock.patch.object(sanitize_android_artifact.shutil, "move"):
                sanitize_android_artifact.resign_android_artifact(artifact)

            sign_args = run.call_args.args[0]
            sign_kwargs = run.call_args.kwargs
            self.assertNotIn("-storepass", sign_args)
            self.assertNotIn("-keypass", sign_args)
            self.assertNotIn("store-secret", sign_args)
            self.assertNotIn("key-secret", sign_args)
            self.assertEqual(sign_kwargs["input"], "store-secret\nkey-secret\n")

    def test_signing_config_requires_release_keystore_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = _isolated_gradle_project(Path(tmp))
            with unittest.mock.patch.dict("os.environ", _signing_free_env(Path(tmp)), clear=True):
                with self.assertRaises(RuntimeError):
                    sanitize_android_artifact.signing_config(app_project_dir=app_dir)

    def test_signing_config_allows_debug_keystore_when_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = _isolated_gradle_project(Path(tmp))
            with unittest.mock.patch.dict("os.environ", _signing_free_env(Path(tmp)), clear=True):
                signing = sanitize_android_artifact.signing_config(
                    allow_debug_keystore=True, app_project_dir=app_dir
                )

        self.assertEqual(signing.key_alias, "androiddebugkey")
        self.assertEqual(signing.store_password, "android")
        self.assertEqual(signing.key_password, "android")
        self.assertEqual(signing.keystore, Path.home() / ".android" / "debug.keystore")

    def test_signing_config_reads_gradle_user_home_properties(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app_dir = _isolated_gradle_project(root)
            (root / "gradle-home" / "gradle.properties").write_text(
                "KEYSTORE_FILE=keys/release.jks\n"
                "KEYSTORE_PWD=store-secret\n"
                "KEY_ALIAS : release\n"
                "KEY_PWD   key-secret\n",
                encoding="utf-8",
            )
            with unittest.mock.patch.dict("os.environ", _signing_free_env(root), clear=True):
                signing = sanitize_android_artifact.signing_config(app_project_dir=app_dir)

        self.assertEqual(signing.keystore, app_dir / "keys" / "release.jks")
        self.assertEqual(signing.store_password, "store-secret")
        self.assertEqual(signing.key_alias, "release")
        self.assertEqual(signing.key_password, "key-secret")

    def test_signing_config_gradle_precedence_and_absolute_keystore(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app_dir = _isolated_gradle_project(root)
            (app_dir.parent / "gradle.properties").write_text(
                "KEYSTORE_FILE=/project/release.jks\nKEYSTORE_PWD=project\n"
                "KEY_ALIAS=project\nKEY_PWD=project\n",
                encoding="utf-8",
            )
            (root / "gradle-home" / "gradle.properties").write_text(
                "KEYSTORE_PWD=user-home\n", encoding="utf-8"
            )
            env = _signing_free_env(root)
            env["ORG_GRADLE_PROJECT_KEY_PWD"] = "from-env"
            with unittest.mock.patch.dict("os.environ", env, clear=True):
                signing = sanitize_android_artifact.signing_config(app_project_dir=app_dir)

        self.assertEqual(signing.keystore, Path("/project/release.jks"))
        self.assertEqual(signing.store_password, "user-home")
        self.assertEqual(signing.key_alias, "project")
        self.assertEqual(signing.key_password, "from-env")

    def test_parse_java_properties_handles_escapes_and_continuations(self) -> None:
        parsed = sanitize_android_artifact.parse_java_properties(
            "# comment\n"
            "! also a comment\n"
            "\n"
            "plain=value\n"
            "spaced  =  padded value\n"
            "colon:value\n"
            "multi=first \\\n"
            "    second\n"
            "escaped\\=key=a\\tb\\u0041\n"
            "path=C:\\\\keys\\\\release.jks\n"
        )

        self.assertEqual(parsed["plain"], "value")
        self.assertEqual(parsed["spaced"], "padded value")
        self.assertEqual(parsed["colon"], "value")
        self.assertEqual(parsed["multi"], "first second")
        self.assertEqual(parsed["escaped=key"], "a\tbA")
        self.assertEqual(parsed["path"], "C:\\keys\\release.jks")
        self.assertNotIn("# comment", parsed)

    def test_android_signing_tools_uses_semantic_build_tools_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sdk = Path(tmp)
            for version in ("9.0.0", "34.0.0-rc1", "34.0.0"):
                tools = sdk / "build-tools" / version
                tools.mkdir(parents=True)
                (tools / "apksigner").write_text("", encoding="utf-8")
                (tools / "zipalign").write_text("", encoding="utf-8")

            with unittest.mock.patch.dict("os.environ", {"ANDROID_SDK_ROOT": str(sdk)}, clear=False):
                zipalign, apksigner = sanitize_android_artifact.android_signing_tools()

            self.assertEqual(apksigner.parent.name, "34.0.0")
            self.assertEqual(zipalign.parent.name, "34.0.0")


if __name__ == "__main__":
    unittest.main()
