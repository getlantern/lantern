// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "app_links", path: "/Users/afisk/.pub-cache/hosted/pub.dev/app_links-6.4.0/ios/app_links"),
        .package(name: "device_info_plus", path: "/Users/afisk/.pub-cache/hosted/pub.dev/device_info_plus-11.5.0/ios/device_info_plus"),
        .package(name: "flutter_local_notifications", path: "/Users/afisk/.pub-cache/hosted/pub.dev/flutter_local_notifications-19.4.0/ios/flutter_local_notifications"),
        .package(name: "flutter_timezone", path: "/Users/afisk/.pub-cache/hosted/pub.dev/flutter_timezone-4.1.1/ios/flutter_timezone"),
        .package(name: "in_app_purchase_storekit", path: "/Users/afisk/.pub-cache/hosted/pub.dev/in_app_purchase_storekit-0.3.22+1/darwin/in_app_purchase_storekit"),
        .package(name: "mobile_scanner", path: "/Users/afisk/.pub-cache/hosted/pub.dev/mobile_scanner-7.0.1/darwin/mobile_scanner"),
        .package(name: "package_info_plus", path: "/Users/afisk/.pub-cache/hosted/pub.dev/package_info_plus-8.3.0/ios/package_info_plus"),
        .package(name: "path_provider_foundation", path: "/Users/afisk/.pub-cache/hosted/pub.dev/path_provider_foundation-2.4.1/darwin/path_provider_foundation"),
        .package(name: "sentry_flutter", path: "/Users/afisk/.pub-cache/hosted/pub.dev/sentry_flutter-9.6.0/ios/sentry_flutter"),
        .package(name: "share_plus", path: "/Users/afisk/.pub-cache/hosted/pub.dev/share_plus-11.0.0/ios/share_plus"),
        .package(name: "shared_preferences_foundation", path: "/Users/afisk/.pub-cache/hosted/pub.dev/shared_preferences_foundation-2.5.4/darwin/shared_preferences_foundation"),
        .package(name: "stripe_ios", path: "/Users/afisk/.pub-cache/hosted/pub.dev/stripe_ios-11.5.0/ios/stripe_ios"),
        .package(name: "url_launcher_ios", path: "/Users/afisk/.pub-cache/hosted/pub.dev/url_launcher_ios-6.3.3/ios/url_launcher_ios"),
        .package(name: "integration_test", path: "/Users/afisk/flutter/packages/integration_test/ios/integration_test")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "app-links", package: "app_links"),
                .product(name: "device-info-plus", package: "device_info_plus"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "flutter-timezone", package: "flutter_timezone"),
                .product(name: "in-app-purchase-storekit", package: "in_app_purchase_storekit"),
                .product(name: "mobile-scanner", package: "mobile_scanner"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "sentry-flutter", package: "sentry_flutter"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "stripe-ios", package: "stripe_ios"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "integration-test", package: "integration_test")
            ]
        )
    ]
)
