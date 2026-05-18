#!/usr/bin/env python3

from __future__ import annotations

import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import android_manifest_filter as manifest_filter


ANDROID = "{http://schemas.android.com/apk/res/android}"
TOOLS = "{http://schemas.android.com/tools}"


BASE_MANIFEST = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="com.android.vending.BILLING" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <application android:name=".LanternApp" android:usesCleartextTraffic="true">
        <activity android:name=".MainActivity">
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
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver" />
        <activity android:name="com.android.billingclient.api.ProxyBillingActivity" />
        <activity android:name="com.stripe.android.paymentsheet.PaymentSheetActivity" />
        <provider android:name="com.google.mlkit.common.internal.MlKitInitProvider" />
        <meta-data
            android:name="com.google.android.gms.wallet.api.enabled"
            android:value="true" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="alipays" />
        </intent>
        <package android:name="com.eg.android.AlipayGphone" />
    </queries>
</manifest>
"""


class AndroidManifestFilterTest(unittest.TestCase):
    def test_normal_vpn_and_novpn_manifest_diffs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            normal = root / "AndroidManifest.xml"
            vpn = root / "AndroidManifest.vpn.xml"
            novpn = root / "AndroidManifest.novpn.xml"
            normal.write_text(BASE_MANIFEST, encoding="utf-8")

            manifest_filter.filter_manifest(normal, vpn, "vpn")
            manifest_filter.filter_manifest(normal, novpn, "novpn")

            self.assertEqual(
                self.manifest_summary(normal),
                {
                    "cleartext": "true",
                    "application": ".LanternApp",
                    "permissions": {
                        "android.permission.ACCESS_WIFI_STATE",
                        "android.permission.CAMERA",
                        "android.permission.CHANGE_NETWORK_STATE",
                        "android.permission.FOREGROUND_SERVICE",
                        "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
                        "android.permission.INTERNET",
                        "android.permission.QUERY_ALL_PACKAGES",
                        "android.permission.RECEIVE_BOOT_COMPLETED",
                        "android.permission.WRITE_SETTINGS",
                        "com.android.vending.BILLING",
                    },
                    "features": {"android.hardware.camera"},
                    "activities": {
                        ".MainActivity",
                        "com.android.billingclient.api.ProxyBillingActivity",
                        "com.stripe.android.paymentsheet.PaymentSheetActivity",
                    },
                    "activity_filters": 2,
                    "services": {
                        ".service.LanternVpnService",
                        ".service.QuickTileService",
                    },
                    "providers": {"com.google.mlkit.common.internal.MlKitInitProvider"},
                    "receivers": {
                        "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
                        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
                    },
                    "wallet_metadata": True,
                    "queries": 3,
                    "queries_remove_all": False,
                    "remove_stubs": False,
                },
            )
            self.assertEqual(
                self.manifest_summary(vpn),
                {
                    "cleartext": "false",
                    "application": "foundation.bridge.AppHost",
                    "permissions": {
                        "android.permission.ACCESS_WIFI_STATE",
                        "android.permission.CHANGE_NETWORK_STATE",
                        "android.permission.FOREGROUND_SERVICE",
                        "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
                        "android.permission.INTERNET",
                    },
                    "features": set(),
                    "activities": {"foundation.bridge.HomeActivity"},
                    "activity_filters": 0,
                    "services": {"foundation.bridge.NetworkService"},
                    "providers": set(),
                    "receivers": set(),
                    "wallet_metadata": False,
                    "queries": 0,
                    "queries_remove_all": True,
                    "remove_stubs": True,
                },
            )
            self.assertEqual(
                self.manifest_summary(novpn),
                {
                    "cleartext": "false",
                    "application": "foundation.bridge.AppHost",
                    "permissions": {
                        "android.permission.FOREGROUND_SERVICE",
                        "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
                        "android.permission.INTERNET",
                    },
                    "features": set(),
                    "activities": {"foundation.bridge.HomeActivity"},
                    "activity_filters": 0,
                    "services": {"foundation.bridge.SyncService"},
                    "providers": set(),
                    "receivers": set(),
                    "wallet_metadata": False,
                    "queries": 0,
                    "queries_remove_all": True,
                    "remove_stubs": True,
                },
            )

    def manifest_summary(self, path: Path) -> dict[str, object]:
        root = ET.parse(path).getroot()
        application = root.find("application")
        queries = root.find("queries")
        assert application is not None

        def remove_stub(element: ET.Element) -> bool:
            return element.attrib.get(f"{TOOLS}node") == "remove"

        return {
            "cleartext": application.attrib.get(f"{ANDROID}usesCleartextTraffic"),
            "application": application.attrib.get(f"{ANDROID}name"),
            "permissions": {
                element.attrib[f"{ANDROID}name"]
                for element in root.findall("uses-permission")
                if not remove_stub(element)
            },
            "features": {
                element.attrib[f"{ANDROID}name"]
                for element in root.findall("uses-feature")
                if not remove_stub(element)
            },
            "activities": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("activity")
                if not remove_stub(element)
            },
            "activity_filters": sum(
                len(activity.findall("intent-filter"))
                for activity in application.findall("activity")
                if not remove_stub(activity)
            ),
            "services": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("service")
                if not remove_stub(element)
            },
            "providers": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("provider")
                if not remove_stub(element)
            },
            "receivers": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("receiver")
                if not remove_stub(element)
            },
            "wallet_metadata": any(
                element.attrib.get(f"{ANDROID}name")
                == "com.google.android.gms.wallet.api.enabled"
                for element in application.findall("meta-data")
                if not remove_stub(element)
            ),
            "queries": len(queries) if queries is not None else 0,
            "queries_remove_all": (
                queries is not None and queries.attrib.get(f"{TOOLS}node") == "removeAll"
            ),
            "remove_stubs": any(
                remove_stub(element) for element in list(root) + list(application)
            ),
        }


if __name__ == "__main__":
    unittest.main()
