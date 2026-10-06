import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import shlex

import bundle


class BundleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        assets = {}
        for role in ("seed", "bridge", "installer", "probe", "global_checker"):
            raw = bytearray(128)
            raw[:2] = b"MZ"
            raw[60:64] = (64).to_bytes(4, "little")
            raw[64:70] = b"PE\0\0" + (0x8664 if role == "probe" else 0x14C).to_bytes(2, "little")
            (self.root / (role + ".exe")).write_bytes(raw)
            assets[role] = {"file": role + ".exe", "sha256": hashlib.sha256(raw).hexdigest()}
            if role in {"seed", "bridge", "installer"}:
                assets[role]["signer_thumbprint"] = "A" * 40
        config = json.dumps({"updateserverurl": "https://update.staging.iantem.io",
                             "autoupdateca": "-----BEGIN CERTIFICATE-----\ntest\n",
                             "trustedcas": [{"cert": "test"}],
                             "client": {"fronted": {"providers": {"test": {"masquerades": []}}}}})
        (self.root / "global.json").write_text(config)
        assets["global_config"] = {"file": "global.json", "sha256": hashlib.sha256(config.encode()).hexdigest()}
        self.m = dict(schema_version=1, run_id="a" * 32, lane="rebuilt-staging", scenario="success",
                      endpoint=bundle.ENDPOINT, catalog=bundle.CATALOG, artifacts=assets,
                      bridge_version="7.9.6", installer_version="10.2.0", account_environment="staging",
                      production_activation_ready=False, probe_url="https://example.org/health",
                      source_commits={r: "b" * 40 for r in ["seed", "lantern", "lantern-cloud", "lantern-desktop", "radiance"]})
        self.m["source_commits"]["seed"] = bundle.SEED_COMMIT

    def validate(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.m))
        return bundle.validate(self.root, bundle.sha256(path))

    def test_valid(self):
        self.assertEqual(self.validate()["lane"], "rebuilt-staging")

    def test_fail_closed_contract(self):
        for key, value in [("lane", "released-7.9.5"), ("endpoint", "https://update.getlantern.org"),
                           ("catalog", "getlantern/lantern"), ("bridge_version", "7.9.5"),
                           ("bridge_version", "7.10.0-rc.1"), ("installer_version", "11.0.0"),
                           ("account_environment", "prod"), ("production_activation_ready", True),
                           ("probe_url", "https://token@example.org/health"), ("scenario", "skip")]:
            with self.subTest(key=key, value=value):
                old = self.m[key]
                self.m[key] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.m[key] = old

    def test_path_traversal(self):
        for path in ["../seed.exe", "C:/seed.exe", "seed.exe:stream", "\\\\host\\seed.exe", "/seed.exe"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                bundle.local_file(self.root, path)

    def test_wrong_arch_and_tamper(self):
        self.m["artifacts"]["probe"] = copy.deepcopy(self.m["artifacts"]["seed"])
        del self.m["artifacts"]["probe"]["signer_thumbprint"]
        with self.assertRaisesRegex(ValueError, "wrong_pe_arch"):
            self.validate()
        self.m["artifacts"]["seed"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "asset_hash_mismatch"):
            self.validate()

    def test_symlink(self):
        (self.root / "linked.exe").symlink_to(self.root / "seed.exe")
        with self.assertRaises(ValueError):
            bundle.local_file(self.root, "linked.exe")

    def test_actual_binary_metadata_contract(self):
        flags = ('-H=windowsgui -X github.com/getlantern/lantern-desktop/desktop.ApplicationVersion=7.9.5 '
                 '-X github.com/getlantern/flashlight/v7/common.ProAPIHost=api-staging.getiantem.org')
        def info(flags):
            return ('seed.exe: go1.22.4\n\tpath\tgithub.com/getlantern/lantern-desktop/main\n'
                    '\tbuild\tGOOS=windows\n\tbuild\tGOARCH=386\n\tbuild\tvcs.modified=false\n'
                    '\tbuild\tvcs.revision=' + bundle.SEED_COMMIT + '\n'
                    '\tbuild\t-tags=lantern,walk_use_cgo\n\tbuild\t-ldflags=' + shlex.quote(flags) + '\n')
        bundle.verify_legacy_build(info(flags), 'seed', bundle.SEED_COMMIT, '7.9.5')
        for invalid in [flags.replace('api-staging.getiantem.org', 'api.getiantem.org'),
                        flags + ' -X github.com/getlantern/flashlight/v7/common.ProAPIHost=api.getiantem.org',
                        flags + ' -X github.com/getlantern/lantern-desktop/autoupdate.PublicKey=changed',
                        flags + ' -X github.com/getlantern/flashlight/v7/common.StagingMode=true']:
            with self.subTest(flags=invalid), self.assertRaises(ValueError):
                bundle.verify_legacy_build(info(invalid), 'seed', bundle.SEED_COMMIT, '7.9.5')


if __name__ == "__main__":
    unittest.main()
