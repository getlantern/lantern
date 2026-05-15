#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile
from contextlib import redirect_stderr, redirect_stdout
import io

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_leakage


class LeakageScannerTest(unittest.TestCase):
    def write_config(self, root: Path) -> Path:
        config = {
            "categories": {
                "brand": {
                    "description": "brand leak",
                    "tokens": ["Lantern"]
                },
                "novpn": {
                    "description": "novpn leak",
                    "tokens": ["android.net.VpnService"]
                }
            },
            "modes": {
                "stealth": {
                    "categories": ["brand"],
                    "allowlist": [
                        {
                            "token": "Lantern",
                            "location": "*allowed.txt",
                            "reason": "test allowlist"
                        }
                    ]
                },
                "stealth-novpn": {
                    "extends": "stealth",
                    "categories": ["novpn"]
                }
            }
        }
        path = root / "tokens.json"
        path.write_text(json.dumps(config), encoding="utf-8")
        return path

    def scan(self, config_path: Path, mode: str, *paths: Path) -> int:
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return check_leakage.main([
                "--config",
                str(config_path),
                "--mode",
                mode,
                *[str(path) for path in paths],
            ])

    def test_detects_forbidden_token_in_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            target = root / "out"
            target.mkdir()
            (target / "classes.dex").write_bytes(b"prefix Lantern suffix")

            self.assertEqual(self.scan(config, "stealth", target), 1)

    def test_scans_zip_entry_content_and_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/Lantern.txt", b"no content leak here")

            self.assertEqual(self.scan(config, "stealth", archive), 1)

    def test_mode_specific_allowlist(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            target = root / "allowed.txt"
            target.write_bytes(b"Lantern")

            self.assertEqual(self.scan(config, "stealth", target), 0)

    def test_stealth_novpn_extends_base_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            target = root / "manifest.bin"
            target.write_text("android.net.VpnService", encoding="utf-8")

            self.assertEqual(self.scan(config, "stealth", target), 0)
            self.assertEqual(self.scan(config, "stealth-novpn", target), 1)

    def test_missing_ok_skips_absent_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            missing = root / "missing.apk"

            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                code = check_leakage.main([
                    "--config",
                    str(config),
                    "--missing-ok",
                    str(missing),
                ])
            self.assertEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
