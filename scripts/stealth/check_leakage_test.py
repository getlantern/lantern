#!/usr/bin/env python3
import json
from pathlib import Path
import sys
import struct
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

    def test_direct_target_filename_is_not_scanned(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "Lantern.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/clean.txt", b"no content leak here")

            self.assertEqual(self.scan(config, "stealth", archive), 0)

    def test_directory_child_filename_is_scanned(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            target = root / "out"
            target.mkdir()
            (target / "Lantern.txt").write_bytes(b"no content leak here")

            self.assertEqual(self.scan(config, "stealth", target), 1)

    def test_scans_zip_archive_comment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/clean.txt", b"no content leak here")
                zf.comment = b"archive comment mentions Lantern"

            self.assertEqual(self.scan(config, "stealth", archive), 1)

    def test_archive_entry_allowlist_is_not_shadowed_by_raw_archive_scan(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/allowed.txt", b"Lantern")

            self.assertEqual(self.scan(config, "stealth", archive), 0)

    def test_scans_zip_entry_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            info = zipfile.ZipInfo("assets/clean.txt")
            info.extra = b"\x99\x99\x07\x00Lantern"
            info.comment = b"Lantern comment metadata"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr(info, b"clean")

            self.assertEqual(self.scan(config, "stealth", archive), 1)

    def test_scans_zip_local_header_extra_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/clean.txt", b"clean")

            archive.write_bytes(self.insert_local_extra(
                archive.read_bytes(),
                "assets/clean.txt",
                b"\x99\x99\x07\x00Lantern",
            ))

            self.assertEqual(self.scan(config, "stealth", archive), 1)

    def test_scans_non_entry_archive_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            archive = root / "app.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.writestr("assets/clean.txt", b"clean")

            archive.write_bytes(self.insert_before_central_directory(
                archive.read_bytes(),
                b"Lantern signing block",
            ))

            self.assertEqual(self.scan(config, "stealth", archive), 1)

    def test_mode_specific_allowlist(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            target = root / "allowed.txt"
            target.write_bytes(b"Lantern")

            self.assertEqual(self.scan(config, "stealth", target), 0)

    def test_rejects_allowlist_entries_without_matchers(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            data = json.loads(config.read_text(encoding="utf-8"))
            data["modes"]["stealth"]["allowlist"] = [{"reason": "too broad"}]
            config.write_text(json.dumps(data), encoding="utf-8")
            target = root / "classes.dex"
            target.write_bytes(b"Lantern")

            self.assertEqual(self.scan(config, "stealth", target), 2)

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

    def test_scanner_errors_do_not_print_success(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            config = self.write_config(root)
            nested = root / "inner.apk"
            with zipfile.ZipFile(nested, "w") as zf:
                zf.writestr("assets/clean.txt", b"clean")
            archive = root / "outer.apk"
            with zipfile.ZipFile(archive, "w") as zf:
                zf.write(nested, "inner.apk")

            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                code = check_leakage.main([
                    "--config",
                    str(config),
                    "--max-depth",
                    "0",
                    str(archive),
                ])

            self.assertEqual(code, 2)
            self.assertNotIn("Stealth leakage check passed", stdout.getvalue())
            self.assertNotIn("Forbidden identifiers found", stdout.getvalue())
            self.assertIn("failed", stdout.getvalue())
            self.assertIn("Scanner errors", stderr.getvalue())

    def insert_before_central_directory(self, data: bytes, payload: bytes) -> bytes:
        eocd_offset = data.rfind(b"PK\x05\x06")
        self.assertNotEqual(eocd_offset, -1)
        central_dir_offset = struct.unpack_from("<I", data, eocd_offset + 16)[0]
        out = data[:central_dir_offset] + payload + data[central_dir_offset:]
        new_eocd_offset = eocd_offset + len(payload)
        out = bytearray(out)
        struct.pack_into("<I", out, new_eocd_offset + 16, central_dir_offset + len(payload))
        return bytes(out)

    def insert_local_extra(self, data: bytes, entry_name: str, payload: bytes) -> bytes:
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            header_offset = zf.getinfo(entry_name).header_offset
        (
            signature,
            _version,
            _flags,
            _compression,
            _mtime,
            _mdate,
            _crc,
            _compressed_size,
            _file_size,
            filename_len,
            extra_len,
        ) = struct.unpack_from("<IHHHHHIIIHH", data, header_offset)
        self.assertEqual(signature, 0x04034B50)
        insert_at = header_offset + 30 + filename_len + extra_len
        eocd_offset = data.rfind(b"PK\x05\x06")
        self.assertNotEqual(eocd_offset, -1)
        central_dir_offset = struct.unpack_from("<I", data, eocd_offset + 16)[0]
        out = bytearray(data[:insert_at] + payload + data[insert_at:])
        struct.pack_into("<H", out, header_offset + 28, extra_len + len(payload))
        struct.pack_into("<I", out, eocd_offset + len(payload) + 16, central_dir_offset + len(payload))
        return bytes(out)


if __name__ == "__main__":
    unittest.main()
