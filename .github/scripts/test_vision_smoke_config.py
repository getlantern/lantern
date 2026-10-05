import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

import vision_smoke_config


VISION_URL = (
    "vless://11111111-1111-4111-8111-111111111111@example.test:443"
    "?security=tls&flow=xtls-rprx-vision#smoke"
)
REALITY_URL = VISION_URL.replace("security=tls", "security=reality").replace(
    "#smoke", "&pbk=" + "A" * 43 + "&sid=ab01#smoke"
)


class VisionConfigTests(unittest.TestCase):
    def test_selects_vision_from_mixed_roster(self):
        raw = "ss://unused@example.test:443\n" + VISION_URL
        self.assertEqual(vision_smoke_config.select_vision_url(raw), VISION_URL)

    def test_preserves_query_commas_and_accepts_comma_separated_roster(self):
        url = VISION_URL.replace("#smoke", "&alpn=h2,http%2F1.1#smoke")
        self.assertEqual(
            vision_smoke_config.select_vision_url("ss://unused@host:443," + url),
            url.replace(",", "%2C"),
        )

    def test_skips_insecure_vision_when_verified_vision_is_available(self):
        insecure = VISION_URL.replace("#smoke", "&allowInsecure=true#smoke")
        self.assertEqual(
            vision_smoke_config.select_vision_url(insecure + "\n" + VISION_URL),
            VISION_URL,
        )

    def test_accepts_reality_and_verified_tls(self):
        for url in (
            REALITY_URL,
            VISION_URL.replace("#smoke", "&allowInsecure=0#smoke"),
        ):
            with self.subTest(url=url):
                self.assertEqual(vision_smoke_config.select_vision_url(url), url)

    def test_rejects_missing_vision_and_insecure_configurations(self):
        for url in (
            "", VISION_URL.replace("vless://", "trojan://"),
            VISION_URL.replace("vless://", "vless://%zz"),
            VISION_URL.replace("flow=xtls-rprx-vision", "flow="),
            VISION_URL.replace("security=tls", "security=none"),
            VISION_URL.replace("security=tls", "security=reality"),
            REALITY_URL.replace("A" * 43, "invalid-key"),
            REALITY_URL.replace("sid=ab01", "sid=abc"),
            VISION_URL.replace(":443", ":invalid"),
            VISION_URL.replace(":443", ":0"),
            VISION_URL.replace("#smoke", "&flow=other#smoke"),
            VISION_URL.replace("#smoke", "&type=ws#smoke"),
            VISION_URL.replace("#smoke", "&allowInsecure=1#smoke"),
            VISION_URL.replace("#smoke", "&skip_cert_verify=true#smoke"),
        ):
            with self.subTest(url=url):
                with self.assertRaises(ValueError):
                    vision_smoke_config.select_vision_url(url)

    def test_file_is_private_when_replacing_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "vision-server-urls"
            path.write_text("stale")
            path.chmod(0o644)
            vision_smoke_config.write_private_config(path, VISION_URL)
            self.assertEqual(path.read_text(), VISION_URL + "\n")
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_rejected_secret_is_not_logged(self):
        secret = VISION_URL.replace(":443", ":private-malformed-port")
        result = subprocess.run(
            [sys.executable, str(Path(vision_smoke_config.__file__))],
            env={**os.environ, "JOIN_SERVER_CONFIG_URLS": secret},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(secret, result.stdout + result.stderr)
        self.assertNotIn("private-malformed-port", result.stdout + result.stderr)

    def test_masks_url_without_fragment_and_encoded_userinfo(self):
        secret = VISION_URL.replace("11111111-", "%311111111-", 1)
        result = subprocess.run(
            [sys.executable, str(Path(vision_smoke_config.__file__)), "--mask"],
            env={**os.environ, "JOIN_SERVER_CONFIG_URLS": secret},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("::add-mask::" + secret.replace("%", "%25"), result.stdout)
        self.assertIn(
            "::add-mask::" + secret.split("#")[0].replace("%", "%25") + "\n",
            result.stdout,
        )
        self.assertIn(
            "::add-mask::11111111-1111-4111-8111-111111111111\n", result.stdout
        )


if __name__ == "__main__":
    unittest.main()
