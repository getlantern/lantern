#!/usr/bin/env python3
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))

import sanitize_android_artifact


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
            self.assertGreaterEqual(result.scrubbed_native_strings, 5)
            with zipfile.ZipFile(artifact) as zf:
                self.assertNotIn(
                    "BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map",
                    zf.namelist(),
                )
                scrubbed = zf.read("base/lib/arm64-v8a/libgojni.so")
            self.assertEqual(len(native), len(scrubbed))
            self.assertNotIn(b"getlantern", scrubbed)
            self.assertNotIn(b"Lantern", scrubbed)
            self.assertNotIn(b"VPN", scrubbed)
            self.assertNotIn(b"TUN", scrubbed)
            self.assertNotIn(b"TunOptions", scrubbed)

    def test_does_not_scrub_non_native_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            artifact = Path(tmp) / "app.apk"
            with zipfile.ZipFile(artifact, "w") as zf:
                zf.writestr("classes.dex", b"Lantern VPN")

            result = sanitize_android_artifact.sanitize_zip(artifact)

            self.assertEqual(result.scrubbed_native_strings, 0)
            with zipfile.ZipFile(artifact) as zf:
                self.assertEqual(zf.read("classes.dex"), b"Lantern VPN")

    def test_does_not_fallback_to_whole_file_scrub_for_unparsed_elf(self) -> None:
        data = b"\x7fELF" + b"\x00" * 64 + b"JNI_SYMBOL_VpnService"

        scrubbed, replacements = sanitize_android_artifact.scrub_native_text(data)

        self.assertEqual(replacements, 0)
        self.assertEqual(scrubbed, data)

    def test_elf_no_replacements_does_not_fallback_to_full_file_scrub(self) -> None:
        elf_bytes = b"\x7fELFfakebinary"
        with mock.patch.object(
            sanitize_android_artifact,
            "scrub_elf_text_sections",
            return_value=(elf_bytes, 0),
        ) as scrub_elf, mock.patch.object(
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

            with mock.patch.object(sanitize_android_artifact, "signing_config", return_value=signing), \
                    mock.patch.object(
                        sanitize_android_artifact,
                        "android_signing_tools",
                        return_value=(root / "zipalign", root / "apksigner"),
                    ), \
                    mock.patch.object(sanitize_android_artifact.subprocess, "run") as run, \
                    mock.patch.object(sanitize_android_artifact.shutil, "move"):
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

            with mock.patch.object(sanitize_android_artifact, "signing_config", return_value=signing), \
                    mock.patch.object(sanitize_android_artifact.subprocess, "run") as run, \
                    mock.patch.object(sanitize_android_artifact.shutil, "move"):
                sanitize_android_artifact.resign_android_artifact(artifact)

            sign_args = run.call_args.args[0]
            sign_kwargs = run.call_args.kwargs
            self.assertNotIn("-storepass", sign_args)
            self.assertNotIn("-keypass", sign_args)
            self.assertNotIn("store-secret", sign_args)
            self.assertNotIn("key-secret", sign_args)
            self.assertEqual(sign_kwargs["input"], "store-secret\nkey-secret\n")

    def test_android_signing_tools_uses_semantic_build_tools_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            sdk = Path(tmp)
            for version in ("9.0.0", "34.0.0-rc1", "34.0.0"):
                tools = sdk / "build-tools" / version
                tools.mkdir(parents=True)
                (tools / "apksigner").write_text("", encoding="utf-8")
                (tools / "zipalign").write_text("", encoding="utf-8")

            with mock.patch.dict("os.environ", {"ANDROID_SDK_ROOT": str(sdk)}, clear=False):
                zipalign, apksigner = sanitize_android_artifact.android_signing_tools()

            self.assertEqual(apksigner.parent.name, "34.0.0")
            self.assertEqual(zipalign.parent.name, "34.0.0")


if __name__ == "__main__":
    unittest.main()
