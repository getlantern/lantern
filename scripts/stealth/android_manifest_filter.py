#!/usr/bin/env python3
"""Generate minimized Android manifests for stealth build modes."""

import argparse
import io
from pathlib import Path
import xml.etree.ElementTree as ET


ANDROID_URI = "http://schemas.android.com/apk/res/android"
TOOLS_URI = "http://schemas.android.com/tools"
ANDROID_NAME = f"{{{ANDROID_URI}}}name"
ANDROID_HOST = f"{{{ANDROID_URI}}}host"
ANDROID_SCHEME = f"{{{ANDROID_URI}}}scheme"
ANDROID_CLEAR_TEXT = f"{{{ANDROID_URI}}}usesCleartextTraffic"
ANDROID_PERMISSION = f"{{{ANDROID_URI}}}permission"

STEALTH_MODES = {"vpn", "novpn"}

STEALTH_REMOVE_PERMISSIONS = {
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.WRITE_SETTINGS",
}

NOVPN_REMOVE_PERMISSIONS = STEALTH_REMOVE_PERMISSIONS | {
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.CHANGE_NETWORK_STATE",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
    "android.permission.RECEIVE_BOOT_COMPLETED",
}

DEEPLINK_HOSTS = {"lantern.io", "www.lantern.io"}
DEEPLINK_SCHEMES = {"lantern"}

PAYMENT_QUERY_SCHEMES = {"alipay", "alipays"}
PAYMENT_QUERY_PACKAGES = {"com.eg.android.AlipayGphone"}


def android_attr(element: ET.Element, attr_name: str) -> str:
    return element.attrib.get(attr_name, "")


def has_vpn_intent_filter(service: ET.Element) -> bool:
    for intent_filter in service.findall("intent-filter"):
        for action in intent_filter.findall("action"):
            if android_attr(action, ANDROID_NAME) == "android.net.VpnService":
                return True
    return False


def is_quick_tile_service(service: ET.Element) -> bool:
    return android_attr(service, ANDROID_PERMISSION) == "android.permission.BIND_QUICK_SETTINGS_TILE"


def is_deeplink_intent_filter(intent_filter: ET.Element) -> bool:
    for data in intent_filter.findall("data"):
        if android_attr(data, ANDROID_SCHEME) in DEEPLINK_SCHEMES:
            return True
        if android_attr(data, ANDROID_HOST) in DEEPLINK_HOSTS:
            return True
    return False


def is_payment_query_intent(intent: ET.Element) -> bool:
    for data in intent.findall("data"):
        if android_attr(data, ANDROID_SCHEME) in PAYMENT_QUERY_SCHEMES:
            return True
    return False


def remove_matching(parent: ET.Element, predicate) -> None:
    for child in list(parent):
        if predicate(child):
            parent.remove(child)


def filter_manifest(input_path: Path, output_path: Path, mode: str) -> None:
    if mode not in STEALTH_MODES:
        raise ValueError(f"unsupported stealth mode {mode!r}")

    ET.register_namespace("android", ANDROID_URI)
    ET.register_namespace("tools", TOOLS_URI)

    tree = ET.parse(input_path)
    root = tree.getroot()

    remove_permissions = STEALTH_REMOVE_PERMISSIONS
    if mode == "novpn":
        remove_permissions = NOVPN_REMOVE_PERMISSIONS

    remove_matching(
        root,
        lambda el: el.tag == "uses-permission"
        and android_attr(el, ANDROID_NAME) in remove_permissions,
    )

    application = root.find("application")
    if application is not None:
        application.set(ANDROID_CLEAR_TEXT, "false")

        for activity in application.findall("activity"):
            remove_matching(
                activity,
                lambda el: el.tag == "intent-filter" and is_deeplink_intent_filter(el),
            )

        remove_matching(
            application,
            lambda el: el.tag == "meta-data"
            and android_attr(el, ANDROID_NAME) == "com.google.android.gms.wallet.api.enabled",
        )

        if mode == "novpn":
            remove_matching(
                application,
                lambda el: el.tag == "service"
                and (
                    android_attr(el, ANDROID_PERMISSION)
                    == "android.permission.BIND_VPN_SERVICE"
                    or has_vpn_intent_filter(el)
                    or is_quick_tile_service(el)
                ),
            )
            remove_matching(
                application,
                lambda el: el.tag == "receiver"
                and android_attr(el, ANDROID_NAME)
                == "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
            )

    queries = root.find("queries")
    if queries is not None:
        remove_matching(queries, lambda el: el.tag == "intent" and is_payment_query_intent(el))
        remove_matching(
            queries,
            lambda el: el.tag == "package"
            and android_attr(el, ANDROID_NAME) in PAYMENT_QUERY_PACKAGES,
        )

    if hasattr(ET, "indent"):
        ET.indent(tree, space="    ")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output = io.BytesIO()
    tree.write(output, encoding="utf-8", xml_declaration=False)
    xml = output.getvalue().decode("utf-8")
    if not xml.endswith("\n"):
        xml += "\n"
    output_path.write_text(xml, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", required=True, choices=sorted(STEALTH_MODES))
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    filter_manifest(args.input, args.output, args.mode)


if __name__ == "__main__":
    main()
