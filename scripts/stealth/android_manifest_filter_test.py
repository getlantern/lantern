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


BASE_MANIFEST = """\
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
    <uses-permission android:name="android.permission.WRITE_SETTINGS" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <application android:usesCleartextTraffic="true">
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
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver" />
        <meta-data
            android:name="com.google.android.gms.wallet.api.enabled"
            android:value="true" />
    </application>
    <queries>
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
                    "permissions": {
                        "android.permission.ACCESS_WIFI_STATE",
                        "android.permission.CHANGE_NETWORK_STATE",
                        "android.permission.FOREGROUND_SERVICE",
                        "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
                        "android.permission.INTERNET",
                        "android.permission.QUERY_ALL_PACKAGES",
                        "android.permission.RECEIVE_BOOT_COMPLETED",
                        "android.permission.WRITE_SETTINGS",
                    },
                    "activity_filters": 2,
                    "services": {
                        ".service.LanternVpnService",
                        ".service.QuickTileService",
                    },
                    "receivers": {
                        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
                    },
                    "wallet_metadata": True,
                    "queries": 2,
                },
            )
            self.assertEqual(
                self.manifest_summary(vpn),
                {
                    "cleartext": "false",
                    "permissions": {
                        "android.permission.ACCESS_WIFI_STATE",
                        "android.permission.CHANGE_NETWORK_STATE",
                        "android.permission.FOREGROUND_SERVICE",
                        "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
                        "android.permission.INTERNET",
                        "android.permission.RECEIVE_BOOT_COMPLETED",
                    },
                    "activity_filters": 0,
                    "services": {
                        ".service.LanternVpnService",
                        ".service.QuickTileService",
                    },
                    "receivers": {
                        "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
                    },
                    "wallet_metadata": False,
                    "queries": 0,
                },
            )
            self.assertEqual(
                self.manifest_summary(novpn),
                {
                    "cleartext": "false",
                    "permissions": {
                        "android.permission.INTERNET",
                    },
                    "activity_filters": 0,
                    "services": set(),
                    "receivers": set(),
                    "wallet_metadata": False,
                    "queries": 0,
                },
            )

    def manifest_summary(self, path: Path) -> dict[str, object]:
        root = ET.parse(path).getroot()
        application = root.find("application")
        queries = root.find("queries")
        assert application is not None
        return {
            "cleartext": application.attrib.get(f"{ANDROID}usesCleartextTraffic"),
            "permissions": {
                element.attrib[f"{ANDROID}name"]
                for element in root.findall("uses-permission")
            },
            "activity_filters": sum(
                len(activity.findall("intent-filter"))
                for activity in application.findall("activity")
            ),
            "services": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("service")
            },
            "receivers": {
                element.attrib[f"{ANDROID}name"]
                for element in application.findall("receiver")
            },
            "wallet_metadata": any(
                element.attrib.get(f"{ANDROID}name")
                == "com.google.android.gms.wallet.api.enabled"
                for element in application.findall("meta-data")
            ),
            "queries": len(queries) if queries is not None else 0,
        }


if __name__ == "__main__":
    unittest.main()
