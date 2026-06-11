import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_profile


class GenerateProfileTest(unittest.TestCase):
    def test_generates_profile_outputs_and_redacts_seed_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            profile_path = root / "profile.json"
            defines_path = root / "dart-defines.json"
            metadata_path = root / "metadata.json"

            exit_code = generate_profile.main(
                [
                    "--mode",
                    "stealth-vpn",
                    "--package-name",
                    "org.example.safe.s123",
                    "--app-name",
                    "Beacon",
                    "--session-name",
                    "BeaconLink",
                    "--go-obfuscation-seed",
                    "seed-for-test",
                    "--denylist-version",
                    "7",
                    "--output",
                    str(profile_path),
                    "--dart-defines-output",
                    str(defines_path),
                    "--artifact-metadata-output",
                    str(metadata_path),
                ]
            )

            self.assertEqual(exit_code, 0)

            profile = json.loads(profile_path.read_text())
            self.assertEqual(profile["mode"], "stealth-vpn")
            self.assertEqual(profile["packageName"], "org.example.safe.s123")
            self.assertEqual(profile["appName"], "Beacon")
            self.assertEqual(profile["sessionName"], "BeaconLink")
            self.assertNotIn("nativeLibraryName", profile)
            self.assertEqual(profile["goObfuscationSeed"], "seed-for-test")
            self.assertEqual(profile["denylistVersion"], 7)

            defines = json.loads(defines_path.read_text())
            self.assertEqual(defines["STEALTH_MODE"], "stealth-vpn")
            self.assertEqual(defines["STEALTH_NO_VPN"], "false")
            self.assertEqual(
                defines["STEALTH_PACKAGE_NAME"], "org.example.safe.s123"
            )
            self.assertNotIn("STEALTH_NATIVE_LIBRARY_NAME", defines)
            self.assertNotIn("STEALTH_GO_OBFUSCATION_SEED", defines)

            metadata = json.loads(metadata_path.read_text())
            self.assertNotIn("goObfuscationSeed", metadata)
            self.assertNotIn("unexpectedPrivateField", metadata)
            self.assertIn("goObfuscationSeedSha256", metadata)

    def test_go_tags_suffix_from_profile(self):
        profile = {
            "mode": "stealth-novpn",
            "packageName": "org.example.safe.s456",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
            "unexpectedPrivateField": "do-not-export",
        }

        normalized = generate_profile.validate_profile(profile)

        self.assertEqual(normalized["mode"], "stealth-novpn")
        self.assertEqual(generate_profile.dart_defines(normalized)["STEALTH_NO_VPN"], "true")
        self.assertEqual(
            generate_profile.go_tags_suffix(normalized),
            ",stealth,stealth_novpn",
        )
        self.assertNotIn(
            "unexpectedPrivateField",
            generate_profile.artifact_metadata(normalized),
        )

    def test_accepts_mode_aliases(self):
        profile = {
            "mode": "novpn",
            "packageName": "org.example.safe.s456",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
        }

        normalized = generate_profile.validate_profile(profile)

        self.assertEqual(normalized["mode"], "stealth-novpn")

    def test_go_tags_suffix_requires_input(self):
        exit_code = generate_profile.main(["--go-tags-suffix"])

        self.assertEqual(exit_code, 2)

    def test_rejects_invalid_package_name(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "bad package",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_rejects_unsupported_schema_version(self):
        profile = {
            "schemaVersion": generate_profile.SCHEMA_VERSION + 1,
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_rejects_boolean_denylist_version(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": True,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_rejects_float_denylist_version(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 1.9,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_rejects_denylist_version_outside_android_int_range(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": "Beacon",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": generate_profile.MAX_ANDROID_INT + 1,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_write_json_wraps_os_errors(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(generate_profile.ProfileError):
                generate_profile.write_json(Path(tmp), {})

    def test_rejects_manifest_placeholder_xml_characters(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": 'Bad "Label"',
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_rejects_manifest_placeholder_iso_control_characters(self):
        profile = {
            "mode": "stealth-vpn",
            "packageName": "org.example.safe.s123",
            "appName": "Bad\x7fLabel",
            "sessionName": "BeaconLink",
            "goObfuscationSeed": "seed-for-test",
            "denylistVersion": 0,
        }

        with self.assertRaises(generate_profile.ProfileError):
            generate_profile.validate_profile(profile)

    def test_default_package_name_is_neutral(self):
        """default_package_name must not embed 'lantern' or 'stealth' tokens."""
        pkg = generate_profile.default_package_name("stl_abcdef")
        self.assertNotIn("lantern", pkg.lower())
        self.assertNotIn("stealth", pkg.lower())
        # Must still be a valid Android application ID
        import re
        self.assertRegex(pkg, r"^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$")

    def test_stealth_build_requires_app_name(self):
        """build_profile must fail-fast when --app-name is absent for stealth modes."""
        with tempfile.TemporaryDirectory() as tmp:
            exit_code = generate_profile.main(
                [
                    "--mode",
                    "stealth-vpn",
                    "--package-name",
                    "org.example.safe.s123",
                    "--session-name",
                    "BeaconLink",
                    "--output",
                    str(Path(tmp) / "profile.json"),
                ]
            )
            self.assertNotEqual(exit_code, 0)

    def test_stealth_build_requires_session_name(self):
        """build_profile must fail-fast when --session-name is absent for stealth modes."""
        with tempfile.TemporaryDirectory() as tmp:
            exit_code = generate_profile.main(
                [
                    "--mode",
                    "stealth-vpn",
                    "--package-name",
                    "org.example.safe.s123",
                    "--app-name",
                    "Beacon",
                    "--output",
                    str(Path(tmp) / "profile.json"),
                ]
            )
            self.assertNotEqual(exit_code, 0)


if __name__ == "__main__":
    unittest.main()
