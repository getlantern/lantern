#!/usr/bin/env python3
"""Generate minimized Android manifests for stealth build modes."""

from __future__ import annotations

import argparse
import io
from pathlib import Path
import xml.etree.ElementTree as ET


ANDROID_URI = "http://schemas.android.com/apk/res/android"
TOOLS_URI = "http://schemas.android.com/tools"
ANDROID_NAME = f"{{{ANDROID_URI}}}name"
ANDROID_CLEAR_TEXT = f"{{{ANDROID_URI}}}usesCleartextTraffic"
ANDROID_PERMISSION = f"{{{ANDROID_URI}}}permission"
ANDROID_EXPORTED = f"{{{ANDROID_URI}}}exported"
ANDROID_FOREGROUND_SERVICE_TYPE = f"{{{ANDROID_URI}}}foregroundServiceType"
ANDROID_VALUE = f"{{{ANDROID_URI}}}value"
TOOLS_NODE = f"{{{TOOLS_URI}}}node"

STEALTH_MODES = {"vpn", "novpn"}

STEALTH_REMOVE_PERMISSIONS = {
    "android.permission.CAMERA",
    "android.permission.QUERY_ALL_PACKAGES",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.WRITE_SETTINGS",
    "com.android.vending.BILLING",
}

STEALTH_REMOVE_FEATURES = {
    "android.hardware.camera",
}

NOVPN_REMOVE_PERMISSIONS = STEALTH_REMOVE_PERMISSIONS | {
    "android.permission.ACCESS_WIFI_STATE",
    "android.permission.CHANGE_NETWORK_STATE",
    "android.permission.FOREGROUND_SERVICE_SYSTEM_EXEMPTED",
}

NOVPN_REQUIRED_PERMISSIONS = {
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
}

STEALTH_REMOVE_META_DATA = {
    "aia-compat-api-min-version",
    "com.google.android.gms.version",
    "com.google.android.gms.wallet.api.enabled",
    "com.google.android.play.billingclient.version",
}

STEALTH_REMOVE_ACTIVITIES = {
    "com.android.billingclient.api.ProxyBillingActivity",
    "com.android.billingclient.api.ProxyBillingActivityV2",
    "com.google.android.gms.common.api.GoogleApiActivity",
    "com.google.android.play.core.common.PlayCoreDialogWrapperActivity",
    "com.stripe.android.attestation.AttestationActivity",
    "com.stripe.android.challenge.confirmation.IntentConfirmationChallengeActivity",
    "com.stripe.android.challenge.passive.PassiveChallengeActivity",
    "com.stripe.android.challenge.passive.warmer.activity.PassiveChallengeWarmerActivity",
    "com.stripe.android.customersheet.CustomerSheetActivity",
    "com.stripe.android.financialconnections.FinancialConnectionsSheetActivity",
    "com.stripe.android.financialconnections.FinancialConnectionsSheetRedirectActivity",
    "com.stripe.android.financialconnections.lite.FinancialConnectionsSheetLiteActivity",
    "com.stripe.android.financialconnections.lite.FinancialConnectionsSheetLiteRedirectActivity",
    "com.stripe.android.financialconnections.ui.FinancialConnectionsSheetNativeActivity",
    "com.stripe.android.googlepaylauncher.GooglePayLauncherActivity",
    "com.stripe.android.googlepaylauncher.GooglePayPaymentMethodLauncherActivity",
    "com.stripe.android.link.LinkActivity",
    "com.stripe.android.link.LinkForegroundActivity",
    "com.stripe.android.link.LinkRedirectHandlerActivity",
    "com.stripe.android.paymentelement.confirmation.cpms.CustomPaymentMethodProxyActivity",
    "com.stripe.android.paymentelement.embedded.form.FormActivity",
    "com.stripe.android.paymentelement.embedded.manage.ManageActivity",
    "com.stripe.android.payments.StripeBrowserLauncherActivity",
    "com.stripe.android.payments.StripeBrowserProxyReturnActivity",
    "com.stripe.android.payments.bankaccount.ui.CollectBankAccountActivity",
    "com.stripe.android.payments.core.authentication.threeds2.Stripe3ds2TransactionActivity",
    "com.stripe.android.payments.paymentlauncher.PaymentLauncherConfirmationActivity",
    "com.stripe.android.paymentsheet.ExternalPaymentMethodProxyActivity",
    "com.stripe.android.paymentsheet.PaymentOptionsActivity",
    "com.stripe.android.paymentsheet.PaymentSheetActivity",
    "com.stripe.android.paymentsheet.addresselement.AddressElementActivity",
    "com.stripe.android.paymentsheet.addresselement.AutocompleteActivity",
    "com.stripe.android.paymentsheet.paymentdatacollection.bacs.BacsMandateConfirmationActivity",
    "com.stripe.android.paymentsheet.paymentdatacollection.cvcrecollection.CvcRecollectionActivity",
    "com.stripe.android.paymentsheet.paymentdatacollection.polling.PollingActivity",
    "com.stripe.android.paymentsheet.ui.SepaMandateActivity",
    "com.stripe.android.shoppay.ShopPayActivity",
    "com.stripe.android.stripe3ds2.views.ChallengeActivity",
    "com.stripe.android.view.PaymentAuthWebViewActivity",
    "com.stripe.android.view.PaymentRelayActivity",
}

STEALTH_REMOVE_SERVICES = {
    "androidx.camera.core.impl.MetadataHolderService",
    "com.google.android.datatransport.runtime.backends.TransportBackendDiscovery",
    "com.google.android.datatransport.runtime.scheduling.jobscheduling.JobInfoSchedulerService",
    "com.google.mlkit.common.internal.MlKitComponentDiscoveryService",
}

STEALTH_REMOVE_PROVIDERS = {
    "com.google.mlkit.common.internal.MlKitInitProvider",
}

STEALTH_REMOVE_RECEIVERS = {
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver",
    "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver",
}

STEALTH_APPLICATION_NAME = "foundation.bridge.AppHost"
STEALTH_ACTIVITY_NAME = "foundation.bridge.HomeActivity"
STEALTH_VPN_SERVICE_NAME = "foundation.bridge.NetworkService"
STEALTH_NOVPN_SERVICE_NAME = "foundation.bridge.SyncService"
NOVPN_SPECIAL_USE_REASON = "User-controlled local proxy connection"

BASE_APPLICATION_NAMES = {".LanternApp", "org.getlantern.lantern.LanternApp"}
BASE_ACTIVITY_NAMES = {".MainActivity", "org.getlantern.lantern.MainActivity"}
BASE_VPN_SERVICE_NAMES = {
    ".service.LanternVpnService",
    "org.getlantern.lantern.service.LanternVpnService",
}
BASE_TILE_SERVICE_NAMES = {
    ".service.QuickTileService",
    "org.getlantern.lantern.service.QuickTileService",
}


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
    has_view_action = any(
        android_attr(action, ANDROID_NAME) == "android.intent.action.VIEW"
        for action in intent_filter.findall("action")
    )
    if not has_view_action:
        return False
    return bool(intent_filter.findall("data"))


def remove_matching(parent: ET.Element, predicate) -> None:
    for child in list(parent):
        if predicate(child):
            parent.remove(child)


def ensure_remove_stub(parent: ET.Element, tag: str, attributes: dict[str, str]) -> None:
    for child in parent.findall(tag):
        if child.attrib.get(TOOLS_NODE) != "remove":
            continue
        if all(child.attrib.get(name) == value for name, value in attributes.items()):
            return

    element = ET.Element(tag)
    for name, value in attributes.items():
        element.set(name, value)
    element.set(TOOLS_NODE, "remove")
    parent.append(element)


def ensure_remove_stubs(parent: ET.Element, tag: str, names: set[str]) -> None:
    for name in sorted(names):
        ensure_remove_stub(parent, tag, {ANDROID_NAME: name})


def ensure_permission(root: ET.Element, permission: str) -> None:
    if any(
        el.tag == "uses-permission" and android_attr(el, ANDROID_NAME) == permission
        for el in root.findall("uses-permission")
    ):
        return
    permission_element = ET.Element("uses-permission")
    permission_element.set(ANDROID_NAME, permission)
    root.insert(0, permission_element)


def rewrite_stealth_components(application: ET.Element) -> None:
    if android_attr(application, ANDROID_NAME) in BASE_APPLICATION_NAMES:
        application.set(ANDROID_NAME, STEALTH_APPLICATION_NAME)

    for activity in application.findall("activity"):
        if android_attr(activity, ANDROID_NAME) in BASE_ACTIVITY_NAMES:
            activity.set(ANDROID_NAME, STEALTH_ACTIVITY_NAME)

    for service in application.findall("service"):
        service_name = android_attr(service, ANDROID_NAME)
        if service_name in BASE_VPN_SERVICE_NAMES:
            service.set(ANDROID_NAME, STEALTH_VPN_SERVICE_NAME)


def ensure_novpn_service(application: ET.Element) -> None:
    if any(
        android_attr(service, ANDROID_NAME) == STEALTH_NOVPN_SERVICE_NAME
        for service in application.findall("service")
    ):
        return

    service = ET.Element("service")
    service.set(ANDROID_NAME, STEALTH_NOVPN_SERVICE_NAME)
    service.set(ANDROID_EXPORTED, "false")
    service.set(ANDROID_FOREGROUND_SERVICE_TYPE, "specialUse")

    special_use = ET.SubElement(service, "property")
    special_use.set(ANDROID_NAME, "android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE")
    special_use.set(ANDROID_VALUE, NOVPN_SPECIAL_USE_REASON)
    application.append(service)


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
    remove_matching(
        root,
        lambda el: el.tag == "uses-feature"
        and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_FEATURES,
    )
    ensure_remove_stubs(root, "uses-permission", remove_permissions)
    ensure_remove_stubs(root, "uses-feature", STEALTH_REMOVE_FEATURES)
    if mode == "novpn":
        for permission in sorted(NOVPN_REQUIRED_PERMISSIONS):
            ensure_permission(root, permission)

    application = root.find("application")
    if application is not None:
        application.set(ANDROID_CLEAR_TEXT, "false")
        rewrite_stealth_components(application)

        for activity in application.findall("activity"):
            remove_matching(
                activity,
                lambda el: el.tag == "intent-filter" and is_deeplink_intent_filter(el),
            )

        remove_matching(
            application,
            lambda el: el.tag == "meta-data"
            and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_META_DATA,
        )
        remove_matching(
            application,
            lambda el: el.tag == "activity"
            and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_ACTIVITIES,
        )
        remove_matching(
            application,
            lambda el: el.tag == "service"
            and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_SERVICES,
        )
        remove_matching(
            application,
            lambda el: el.tag == "provider"
            and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_PROVIDERS,
        )
        remove_matching(
            application,
            lambda el: el.tag == "receiver"
            and android_attr(el, ANDROID_NAME) in STEALTH_REMOVE_RECEIVERS,
        )
        remove_matching(
            application,
            lambda el: el.tag == "service" and is_quick_tile_service(el),
        )
        ensure_remove_stubs(application, "meta-data", STEALTH_REMOVE_META_DATA)
        ensure_remove_stubs(application, "activity", STEALTH_REMOVE_ACTIVITIES)
        ensure_remove_stubs(application, "service", STEALTH_REMOVE_SERVICES)
        ensure_remove_stubs(application, "provider", STEALTH_REMOVE_PROVIDERS)
        ensure_remove_stubs(application, "receiver", STEALTH_REMOVE_RECEIVERS)

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
            ensure_novpn_service(application)

    queries = root.find("queries")
    if queries is not None:
        queries.set(TOOLS_NODE, "removeAll")
        remove_matching(queries, lambda _el: True)

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
