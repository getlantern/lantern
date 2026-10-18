from __future__ import annotations

from pathlib import Path
import os
import shlex
import struct
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile

from verify_android_abis import ELF_ABIS, VerificationError, parse_abis, verify_artifact


ROOT = Path(__file__).resolve().parents[2]


class AndroidAbiBuildContractTest(unittest.TestCase):
    def make(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["make", "--no-print-directory", *args, "APP_VERSION=10.0.0", "GO_SOURCES="],
            cwd=ROOT, env={**os.environ, "GITHUB_ACTIONS": "true", **env},
            capture_output=True, text=True, timeout=30,
        )

    def test_default_maps_gomobile_and_flutter_to_both_abis(self) -> None:
        result = self.make("android-abi-config")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(),
                         "abis=armeabi-v7a,arm64-v8a flutter=android-arm,android-arm64 gomobile=android/arm,android/arm64")

    def test_individual_target_overrides_cannot_drop_one_architecture(self) -> None:
        result = self.make(
            "android-abi-config", "ANDROID_ABI_PROFILE=arm64", "ANDROID_ABIS=arm64-v8a",
            "ANDROID_TARGET_PLATFORMS=android-arm64", "GOMOBILE_ANDROID_TARGET=android/arm64",
            "ANDROID_APK_TARGET_PLATFORMS=android-arm64", "ANDROID_AAB_TARGET_PLATFORMS=android-arm64",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("abis=armeabi-v7a,arm64-v8a", result.stdout)
        self.assertIn("flutter=android-arm,android-arm64", result.stdout)
        self.assertIn("gomobile=android/arm,android/arm64", result.stdout)

    def test_stale_arm64_stamp_invalidates_cached_aar(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            aar, stamp, builds = (work / name for name in ("liblantern.aar", ".abis", "builds"))
            builder = work / "fake-builder.py"
            builder.write_text(
                "import os\nfrom pathlib import Path\n"
                "Path(os.environ['TEST_AAR']).touch()\n"
                "with open(os.environ['TEST_BUILDS'], 'a') as output: output.write('build\\n')\n"
            )
            def build() -> None:
                result = self.make(
                    str(aar), f"ANDROID_LIB_BUILD={aar}", f"ANDROID_ABI_STAMP={stamp}",
                    f"MAKE={shlex.quote(sys.executable)} {shlex.quote(str(builder))}",
                    TEST_AAR=str(aar), TEST_BUILDS=str(builds),
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            build()
            build()
            self.assertEqual(builds.read_text().splitlines(), ["build"])
            # ABI content must invalidate even when the stamp is not newer
            # (including same-second updates under macOS Make 3.81).
            stamp.write_text("arm64-v8a\n")
            newer = time.time() + 60
            os.utime(aar, (newer, newer))
            build()
            build()
            self.assertEqual(builds.read_text().splitlines(), ["build", "build"])
            self.assertEqual(stamp.read_text().strip(), "armeabi-v7a,arm64-v8a")

    def test_standalone_release_preserves_native_build_after_stealth_stamp_refresh(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            aar, copied_aar = work / "liblantern.aar", work / "copied.aar"
            for path in (aar, copied_aar):
                with zipfile.ZipFile(path, "w") as archive:
                    for abi in ELF_ABIS:
                        archive.writestr(f"jni/{abi}/libgojni.so", elf(abi))
            original = aar.read_bytes()
            flutter = work / "flutter"
            # Stop exactly when packaging starts; no Flutter/Gradle build or
            # source transformation is needed to exercise the Make graph.
            flutter.write_text("#!/bin/sh\necho FLUTTER_REACHED\nexit 77\n")
            flutter.chmod(0o755)
            builder = work / "unexpected-native-build.py"
            builder.write_text("print('UNEXPECTED_NATIVE_REBUILD')\nraise SystemExit(66)\n")
            stamp = work / "stealth/profile.stamp"
            common = (
                f"ANDROID_LIB_BUILD={aar}", f"ANDROID_LIB_PATH={copied_aar}",
                f"BUILD_DIR={work}", f"BIN_DIR={work}/bin", f"MAYBE_STEALTH_PROFILE={stamp}",
                "STEALTH_MODE=stealth-vpn", "STEALTH_APP_NAME=Research",
                "STEALTH_PACKAGE_NAME=org.example.research", "STEALTH_SESSION_NAME=Research",
                # Retain the real stealth profile stamp recipe, but skip the
                # Android identity/source/sanitizer steps outside this test.
                "STEALTH_ENABLED=", "STEALTH_PROFILE_ENV=", "STEALTH_FLUTTER_PREFIX=",
                "ANDROID_STEALTH_IDENTITY=0", "ANDROID_GENERATE_IDENTITY_PROFILE=0",
                f"MAKE={shlex.quote(sys.executable)} {shlex.quote(str(builder))}",
            )
            time.sleep(1.1)
            for target in ("android-apk-release", "android-aab-release"):
                with self.subTest(target=target):
                    result = self.make(target, *common, PATH=f"{work}{os.pathsep}{os.environ['PATH']}")
                    self.assertNotEqual(result.returncode, 0)  # fake Flutter deliberately stops the recipe
                    self.assertIn("FLUTTER_REACHED", result.stdout, result.stdout + result.stderr)
                    self.assertIn(f"Verified {aar}", result.stdout)
                    self.assertIn(f"Verified {copied_aar}", result.stdout)
                    self.assertNotIn("UNEXPECTED_NATIVE_REBUILD", result.stdout)
                    self.assertGreater(stamp.stat().st_mtime, aar.stat().st_mtime)
                    self.assertEqual(aar.read_bytes(), original)

            # A copied AAR missing ARM32 must fail before Flutter,
            # without attempting to repair it via the ordinary native build.
            with zipfile.ZipFile(copied_aar, "w") as archive:
                archive.writestr("jni/arm64-v8a/libgojni.so", elf("arm64-v8a"))
            for target in ("android-apk-release", "android-aab-release"):
                with self.subTest(target=target, missing_arm32=True):
                    result = self.make(target, *common, PATH=f"{work}{os.pathsep}{os.environ['PATH']}")
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("missing ABIs armeabi-v7a", result.stderr)
                    self.assertNotIn("FLUTTER_REACHED", result.stdout)
                    self.assertNotIn("UNEXPECTED_NATIVE_REBUILD", result.stdout)


def elf(abi: str) -> bytes:
    header = bytearray(64)
    header[:4] = b"\x7fELF"
    header[4], machine = ELF_ABIS[abi]
    header[5:7] = b"\x01\x01"
    struct.pack_into("<HH", header, 16, 3, machine)
    return bytes(header)


class AndroidAbiVerificationTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.expected = set(ELF_ABIS)

    def artifact(self, kind: str, *, abis: set[str] | None = None, release: bool = True,
                 missing: str = "", incorrect_elf: bool = False, extra: str = "") -> Path:
        path = self.directory / f"app.{kind}"
        prefix = {"aar": "jni", "apk": "lib", "aab": "base/lib"}[kind]
        names = ["libgojni.so"]
        if kind != "aar":
            names += ["libflutter.so"] + (["libapp.so"] if release else [])
        if extra:
            names.append(extra)
        with zipfile.ZipFile(path, "w") as archive:
            for abi in sorted(abis or self.expected):
                for name in names:
                    member = f"{prefix}/{abi}/{name}"
                    if member == missing:
                        continue
                    archive.writestr(member, elf("arm64-v8a" if incorrect_elf else abi))
        return path

    def test_both_architectures_in_each_artifact(self) -> None:
        for kind in ("aar", "apk", "aab"):
            with self.subTest(kind=kind):
                self.assertEqual(set(verify_artifact(self.artifact(kind), kind, self.expected, True)), self.expected)

    def test_either_removed_architecture_fails(self) -> None:
        for kind in ("aar", "apk", "aab"):
            for kept in ELF_ABIS:
                with self.subTest(kind=kind, kept=kept), self.assertRaisesRegex(VerificationError, "missing ABIs"):
                    verify_artifact(self.artifact(kind, abis={kept}), kind, self.expected, True)

    def test_wrong_elf_under_correct_directory_fails(self) -> None:
        with self.assertRaisesRegex(VerificationError, "ELF class/machine"):
            verify_artifact(self.artifact("apk", incorrect_elf=True), "apk", self.expected, True)

    def test_partial_flutter_or_go_packaging_fails(self) -> None:
        for name in ("libflutter.so", "libapp.so", "libgojni.so"):
            with self.subTest(name=name), self.assertRaisesRegex(VerificationError, name):
                path = self.artifact("apk", missing=f"lib/armeabi-v7a/{name}")
                verify_artifact(path, "apk", self.expected, True)

    def test_plugin_library_must_support_both_abis(self) -> None:
        path = self.artifact("aab", extra="libplugin.so", missing="base/lib/armeabi-v7a/libplugin.so")
        with self.assertRaisesRegex(VerificationError, "libplugin.so"):
            verify_artifact(path, "aab", self.expected, True)

    def test_debug_does_not_require_aot_library(self) -> None:
        path = self.artifact("apk", release=False)
        verify_artifact(path, "apk", self.expected)
        with self.assertRaisesRegex(VerificationError, "libapp.so"):
            verify_artifact(path, "apk", self.expected, True)

    def test_debug_apk_allows_arm64_only_optional_vulkan_validation(self) -> None:
        path = self.artifact(
            "apk", release=False, extra="libVkLayer_khronos_validation.so",
            missing="lib/armeabi-v7a/libVkLayer_khronos_validation.so",
        )
        verify_artifact(path, "apk", self.expected)

    def test_release_keeps_strict_vulkan_validation_library_parity(self) -> None:
        path = self.artifact(
            "apk", extra="libVkLayer_khronos_validation.so",
            missing="lib/armeabi-v7a/libVkLayer_khronos_validation.so",
        )
        with self.assertRaisesRegex(VerificationError, "libVkLayer_khronos_validation.so"):
            verify_artifact(path, "apk", self.expected, True)

    def test_debug_optional_vulkan_layer_still_requires_matching_elf(self) -> None:
        path = self.artifact("apk", release=False)
        with zipfile.ZipFile(path, "a") as archive:
            archive.writestr("lib/arm64-v8a/libVkLayer_khronos_validation.so", elf("armeabi-v7a"))
        with self.assertRaisesRegex(VerificationError, "ELF class/machine"):
            verify_artifact(path, "apk", self.expected)

    def test_vulkan_validation_exception_is_only_for_arm32_debug_apks(self) -> None:
        for kind, missing in (
            ("aar", "jni/armeabi-v7a/libVkLayer_khronos_validation.so"),
            ("aab", "base/lib/armeabi-v7a/libVkLayer_khronos_validation.so"),
            ("apk", "lib/arm64-v8a/libVkLayer_khronos_validation.so"),
        ):
            with self.subTest(kind=kind):
                path = self.artifact(kind, extra="libVkLayer_khronos_validation.so", missing=missing)
                with self.assertRaisesRegex(VerificationError, "libVkLayer_khronos_validation.so"):
                    verify_artifact(path, kind, self.expected)

    def test_unexpected_architecture_is_rejected(self) -> None:
        path = self.artifact("aab")
        with zipfile.ZipFile(path, "a") as archive:
            archive.writestr("base/lib/x86/libgojni.so", elf("armeabi-v7a"))
        with self.assertRaisesRegex(VerificationError, "unexpected ABI"):
            verify_artifact(path, "aab", self.expected, True)

    def test_corrupt_native_library_is_rejected(self) -> None:
        path = self.directory / "corrupt.aar"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("jni/arm64-v8a/libgojni.so", b"not an ELF library")
        with self.assertRaisesRegex(VerificationError, "ELF library"):
            verify_artifact(path, "aar", {"arm64-v8a"})

    def test_aab_requires_native_libraries_in_base_module(self) -> None:
        path = self.directory / "feature.aab"
        with zipfile.ZipFile(path, "w") as archive:
            for abi in ELF_ABIS:
                for name in ("libgojni.so", "libflutter.so", "libapp.so"):
                    archive.writestr(f"feature/lib/{abi}/{name}", elf(abi))
        with self.assertRaisesRegex(VerificationError, "base/libgojni.so"):
            verify_artifact(path, "aab", self.expected, True)

    def test_cli_requires_aar_libraries_to_survive_app_packaging(self) -> None:
        aar = self.artifact("aar", extra="libextra.so")
        apk = self.artifact("apk")
        result = subprocess.run(
            [sys.executable, str(Path(__file__).with_name("verify_android_abis.py")),
             "--expected-abis", "armeabi-v7a,arm64-v8a", "--release", "--aar", str(aar), "--apk", str(apk)],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("omitted AAR libraries: libextra.so", result.stderr)

    def cli(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(Path(__file__).with_name("verify_android_abis.py")), *args],
            capture_output=True, text=True,
        )

    def test_cli_per_abi_apk_checked_against_both_abi_aar(self) -> None:
        aar = self.artifact("aar")
        for abi in sorted(ELF_ABIS):
            with self.subTest(abi=abi):
                apk = self.artifact("apk", abis={abi})
                result = self.cli("--expected-abis", "armeabi-v7a,arm64-v8a", "--app-abis", abi,
                                  "--release", "--aar", str(aar), "--apk", str(apk))
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_cli_per_abi_apk_rejects_the_other_abi(self) -> None:
        aar, apk = self.artifact("aar"), self.artifact("apk")
        result = self.cli("--expected-abis", "armeabi-v7a,arm64-v8a", "--app-abis", "arm64-v8a",
                          "--release", "--aar", str(aar), "--apk", str(apk))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected ABI armeabi-v7a", result.stderr)

    def test_cli_per_abi_apk_still_requires_aar_libraries(self) -> None:
        aar = self.artifact("aar", extra="libextra.so")
        apk = self.artifact("apk", abis={"armeabi-v7a"})
        result = self.cli("--expected-abis", "armeabi-v7a,arm64-v8a", "--app-abis", "armeabi-v7a",
                          "--release", "--aar", str(aar), "--apk", str(apk))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("omitted AAR libraries: libextra.so", result.stderr)

    def test_cli_app_abis_must_narrow_expected(self) -> None:
        apk = self.artifact("apk", abis={"armeabi-v7a"})
        result = self.cli("--expected-abis", "arm64-v8a", "--app-abis", "armeabi-v7a", "--apk", str(apk))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("subset", result.stderr)

    def test_bad_abi_selection_fails(self) -> None:
        for value in ("", "armeabi", "arm64-v8a,arm64-v8a", "armeabi-v7a,arm64-v8a,x86_64"):
            with self.subTest(value=value), self.assertRaises(VerificationError):
                parse_abis(value)


if __name__ == "__main__":
    unittest.main()
