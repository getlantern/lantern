#!/usr/bin/env python3
"""Tests for android_manifest_filter.py.

These tests operate on a synthetic merged manifest that includes entries
normally contributed by library AARs (Stripe, Google Play Billing,
Firebase/MLKit).  This mirrors what AGP injects during the merge step, which
is the only point at which the filter runs.

Security invariants tested:
- Every explicitly forbidden permission is absent from the output.
- Every explicitly forbidden activity / service / provider / receiver is absent.
- The <queries> block is removed entirely (package-visibility deanonymisation).
- No tools:node="remove" stubs appear in the output (post-merge stubs would
  survive aapt2 as bare elements, re-adding forbidden entries).
- The launcher activity is preserved and its deep-link intent-filters are
  stripped while the MAIN/LAUNCHER filter is kept.
- Foundation-bridge class aliases replace the base Lantern classes.
- Running the filter twice (idempotency) produces identical output.
- novpn additionally removes VpnService / QuickTile and injects SyncService.
"""

from __future__ import annotations

import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_manifest_filter as f


ANDROID_URI = "http://schemas.android.com/apk/res/android"
ANDROID = f"{{{ANDROID_URI}}}"
TOOLS = "{http://schemas.android.com/tools}"

# A synthetic AGP-merged manifest containing one entry from every category the
# filter is expected to remove.
BASE_MANIFEST = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="com.android.vending.BILLING" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <application
        android:name=".LanternApp"
        android:usesCleartextTraffic="true">
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <data android:scheme="lantern" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <data android:scheme="https" android:host="www.lantern.io" />
            </intent-filter>
        </activity>
        <service
            android:name=".service.LanternVpnService"
            android:permission="android.permission.BIND_VPN_SERVICE">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
        </service>
        <service
            android:name=".service.QuickTileService"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE" />
        <activity android:name="com.android.billingclient.api.ProxyBillingActivity" />
        <activity android:name="com.android.billingclient.api.ProxyBillingActivityV2" />
        <activity android:name="com.stripe.android.paymentsheet.PaymentSheetActivity" />
        <activity android:name="com.stripe.android.paymentsheet.PaymentOptionsActivity" />
        <activity android:name="com.google.android.gms.common.api.GoogleApiActivity" />
        <service android:name="com.google.mlkit.common.internal.MlKitComponentDiscoveryService" />
        <service android:name="com.google.android.datatransport.runtime.backends.TransportBackendDiscovery" />
        <provider android:name="com.google.mlkit.common.internal.MlKitInitProvider" />
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver" />
        <meta-data
            android:name="com.google.android.gms.wallet.api.enabled"
            android:value="true" />
        <meta-data
            android:name="com.google.android.gms.version"
            android:value="12451000" />
    </application>
    <queries>
        <package android:name="com.eg.android.AlipayGphone" />
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="alipays" />
        </intent>
    </queries>
</manifest>
"""


def _parse(path: Path) -> ET.Element:
    return ET.parse(path).getroot()


def _names(elements) -> set[str]:
    return {el.attrib.get(f"{ANDROID}name", "") for el in elements}


def _permissions(root: ET.Element) -> set[str]:
    return _names(root.findall("uses-permission"))


def _features(root: ET.Element) -> set[str]:
    return _names(root.findall("uses-feature"))


def _app(root: ET.Element) -> ET.Element:
    app = root.find("application")
    assert app is not None
    return app


def _no_tools_node_stubs(root: ET.Element) -> bool:
    """Return True iff no element in the manifest carries a tools:node attribute.

    Post-merge, any tools:node="remove" stub would flow to aapt2 which strips
    the tools: namespace but keeps the bare element — re-introducing every
    forbidden entry the filter was supposed to delete.
    """
    tools_node_attr = f"{TOOLS}node"
    for el in root.iter():
        if tools_node_attr in el.attrib:
            return False
    return True


class VpnModeTest(unittest.TestCase):
    """Assertions for --mode vpn."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        tmp = Path(self._tmp.name)
        src = tmp / "AndroidManifest.xml"
        src.write_text(BASE_MANIFEST, encoding="utf-8")
        self.out = tmp / "out.xml"
        f.filter_manifest(src, self.out, "vpn")
        self.root = _parse(self.out)
        self.app = _app(self.root)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    # ── Security: no tools:node stubs ──────────────────────────────────────

    def test_no_tools_node_stubs(self) -> None:
        """filter must never emit tools:node attributes — they survive aapt2 as bare elements."""
        self.assertTrue(_no_tools_node_stubs(self.root))

    # ── Forbidden permissions absent ───────────────────────────────────────

    def test_camera_permission_removed(self) -> None:
        self.assertNotIn("android.permission.CAMERA", _permissions(self.root))

    def test_query_all_packages_removed(self) -> None:
        self.assertNotIn("android.permission.QUERY_ALL_PACKAGES", _permissions(self.root))

    def test_receive_boot_removed(self) -> None:
        self.assertNotIn("android.permission.RECEIVE_BOOT_COMPLETED", _permissions(self.root))

    def test_write_settings_removed(self) -> None:
        self.assertNotIn("android.permission.WRITE_SETTINGS", _permissions(self.root))

    def test_billing_permission_removed(self) -> None:
        self.assertNotIn("com.android.vending.BILLING", _permissions(self.root))

    def test_internet_permission_kept(self) -> None:
        self.assertIn("android.permission.INTERNET", _permissions(self.root))

    # ── Forbidden features absent ──────────────────────────────────────────

    def test_camera_feature_removed(self) -> None:
        self.assertNotIn("android.hardware.camera", _features(self.root))

    # ── Forbidden activities absent ────────────────────────────────────────

    def test_billing_activity_removed(self) -> None:
        activity_names = _names(self.app.findall("activity"))
        self.assertNotIn("com.android.billingclient.api.ProxyBillingActivity", activity_names)
        self.assertNotIn("com.android.billingclient.api.ProxyBillingActivityV2", activity_names)

    def test_stripe_activities_removed(self) -> None:
        activity_names = _names(self.app.findall("activity"))
        self.assertNotIn("com.stripe.android.paymentsheet.PaymentSheetActivity", activity_names)
        self.assertNotIn("com.stripe.android.paymentsheet.PaymentOptionsActivity", activity_names)

    def test_gms_activity_removed(self) -> None:
        activity_names = _names(self.app.findall("activity"))
        self.assertNotIn("com.google.android.gms.common.api.GoogleApiActivity", activity_names)

    # ── Forbidden services absent ──────────────────────────────────────────

    def test_mlkit_service_removed(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertNotIn(
            "com.google.mlkit.common.internal.MlKitComponentDiscoveryService", service_names
        )

    def test_datatransport_service_removed(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertNotIn(
            "com.google.android.datatransport.runtime.backends.TransportBackendDiscovery",
            service_names,
        )

    # ── Forbidden providers absent ─────────────────────────────────────────

    def test_mlkit_provider_removed(self) -> None:
        provider_names = _names(self.app.findall("provider"))
        self.assertNotIn("com.google.mlkit.common.internal.MlKitInitProvider", provider_names)

    # ── Forbidden receivers absent ─────────────────────────────────────────

    def test_boot_receiver_removed(self) -> None:
        receiver_names = _names(self.app.findall("receiver"))
        self.assertNotIn(
            "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
            receiver_names,
        )

    # ── Forbidden metadata absent ──────────────────────────────────────────

    def test_wallet_metadata_removed(self) -> None:
        meta_names = _names(self.app.findall("meta-data"))
        self.assertNotIn("com.google.android.gms.wallet.api.enabled", meta_names)
        self.assertNotIn("com.google.android.gms.version", meta_names)

    # ── queries block removed ──────────────────────────────────────────────

    def test_queries_block_removed(self) -> None:
        self.assertIsNone(self.root.find("queries"))

    # ── Launcher activity preserved, deep-links stripped ──────────────────

    def test_launcher_activity_present(self) -> None:
        activity_names = _names(self.app.findall("activity"))
        self.assertIn("foundation.bridge.HomeActivity", activity_names)

    def test_launcher_filter_kept(self) -> None:
        for activity in self.app.findall("activity"):
            if activity.attrib.get(f"{ANDROID}name") == "foundation.bridge.HomeActivity":
                filters = activity.findall("intent-filter")
                actions = {
                    action.attrib.get(f"{ANDROID}name", "")
                    for fil in filters
                    for action in fil.findall("action")
                }
                self.assertIn("android.intent.action.MAIN", actions)
                return
        self.fail("HomeActivity not found")

    def test_deeplink_filters_stripped(self) -> None:
        for activity in self.app.findall("activity"):
            if activity.attrib.get(f"{ANDROID}name") == "foundation.bridge.HomeActivity":
                for fil in activity.findall("intent-filter"):
                    for data in fil.findall("data"):
                        scheme = data.attrib.get(f"{ANDROID}scheme", "")
                        self.assertNotIn(scheme, ("lantern", "https"),
                            msg=f"deep-link intent-filter with scheme={scheme!r} survived")
                return
        self.fail("HomeActivity not found")

    # ── Class-name rewrite applied ─────────────────────────────────────────

    def test_application_rewritten(self) -> None:
        self.assertEqual(
            self.app.attrib.get(f"{ANDROID}name"), "foundation.bridge.AppHost"
        )

    def test_vpn_service_rewritten(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertIn("foundation.bridge.NetworkService", service_names)
        self.assertNotIn(".service.LanternVpnService", service_names)
        self.assertNotIn("org.getlantern.lantern.service.LanternVpnService", service_names)

    def test_tile_service_rewritten(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertIn("foundation.bridge.ControlTile", service_names)
        self.assertNotIn(".service.QuickTileService", service_names)

    # ── cleartext traffic disabled ─────────────────────────────────────────

    def test_cleartext_disabled(self) -> None:
        self.assertEqual(
            self.app.attrib.get(f"{ANDROID}usesCleartextTraffic"), "false"
        )

    # ── Idempotency ────────────────────────────────────────────────────────

    def test_idempotent(self) -> None:
        tmp2 = tempfile.mkdtemp()
        out2 = Path(tmp2) / "out2.xml"
        f.filter_manifest(self.out, out2, "vpn")
        self.assertEqual(
            self.out.read_text(encoding="utf-8"),
            out2.read_text(encoding="utf-8"),
        )


class NoVpnModeTest(unittest.TestCase):
    """Assertions for --mode novpn (superset of vpn removals)."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        tmp = Path(self._tmp.name)
        src = tmp / "AndroidManifest.xml"
        src.write_text(BASE_MANIFEST, encoding="utf-8")
        self.out = tmp / "out.xml"
        f.filter_manifest(src, self.out, "novpn")
        self.root = _parse(self.out)
        self.app = _app(self.root)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_no_tools_node_stubs(self) -> None:
        self.assertTrue(_no_tools_node_stubs(self.root))

    def test_vpn_permission_removed(self) -> None:
        # ACCESS_WIFI_STATE and CHANGE_NETWORK_STATE are novpn-only removals.
        permissions = _permissions(self.root)
        self.assertNotIn("android.permission.ACCESS_WIFI_STATE", permissions)
        self.assertNotIn("android.permission.CHANGE_NETWORK_STATE", permissions)
        self.assertNotIn("android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED", permissions)

    def test_vpn_service_removed(self) -> None:
        service_names = _names(self.app.findall("service"))
        for name in service_names:
            self.assertNotIn("VpnService", name,
                msg=f"VPN service {name!r} survived novpn filter")

    def test_quick_tile_removed(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertNotIn("foundation.bridge.ControlTile", service_names)

    def test_sync_service_injected(self) -> None:
        service_names = _names(self.app.findall("service"))
        self.assertIn("foundation.bridge.SyncService", service_names)

    def test_foreground_service_permissions_added(self) -> None:
        permissions = _permissions(self.root)
        self.assertIn("android.permission.FOREGROUND_SERVICE", permissions)
        self.assertIn("android.permission.FOREGROUND_SERVICE_SPECIAL_USE", permissions)

    def test_queries_block_removed(self) -> None:
        self.assertIsNone(self.root.find("queries"))

    def test_billing_permission_removed(self) -> None:
        self.assertNotIn("com.android.vending.BILLING", _permissions(self.root))

    def test_idempotent(self) -> None:
        tmp2 = tempfile.mkdtemp()
        out2 = Path(tmp2) / "out2.xml"
        f.filter_manifest(self.out, out2, "novpn")
        self.assertEqual(
            self.out.read_text(encoding="utf-8"),
            out2.read_text(encoding="utf-8"),
        )


class NormalBuildUnaffectedTest(unittest.TestCase):
    """Ensure the filter is not called for normal builds (smoke-test the guard)."""

    def test_invalid_mode_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "in.xml"
            src.write_text(BASE_MANIFEST, encoding="utf-8")
            out = Path(tmp) / "out.xml"
            with self.assertRaises(ValueError):
                f.filter_manifest(src, out, "")
            with self.assertRaises(ValueError):
                f.filter_manifest(src, out, "stealth-vpn")


if __name__ == "__main__":
    unittest.main()
