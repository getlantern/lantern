# Stealth no-VPN leakage source report

Date: 2026-05-18

Branch/worktree: `stealth/integration-final-20260518` in `/tmp/lantern-stealth-integration-20260518`

Primary artifacts inspected:

- `build/stealth-test-artifacts/stealth-novpn/lantern-stealth-novpn.apk`
- `build/stealth-test-artifacts/stealth-novpn/lantern-stealth-novpn.aab`
- Decompiled APK at `/tmp/lantern-novpn-apktool-20260518`

## Executive summary

The no-VPN artifact is not stealth-clean. The manifest-level work is only a partial fix: the final no-VPN APK no longer advertises `VpnService`, `BIND_VPN_SERVICE`, the quick settings tile, Play Billing permission, or the obvious app label/package identity, but the artifact still exposes VPN/TUN/Lantern/payment/OAuth identity through compiled code, Flutter assets, native Go/JNI symbols, third-party Android resources, and AAB metadata.

The biggest sources are:

1. Flutter packages entire asset and locale directories, including `vpn_*`, `lantern_*`, and full `.po` files with VPN, Lantern, billing, OAuth, and social/login strings.
2. Android/Kotlin code is still compiled under `org.getlantern.lantern`, with classes and method-channel names such as `LanternVpnService`, `VPNStatus`, `startVPN`, `stopVPN`, and `org.getlantern.lantern/method`.
3. The no-VPN service still imports TUN/VPN abstractions and calls Go APIs named `Mobile.startVPN()` and `Mobile.stopVPN()`.
4. Flutter still depends on Stripe and Play Billing packages, so Stripe, billing, Google Sign-In, and in-app purchase classes/resources are included even when those features are disabled by flags.
5. `libgojni.so` still exports JNI symbols and strings from gomobile, libbox/sing-box, radiance, and Lantern packages. Garble does not hide exported JNI names required by Java, and current garble scope only covers part of the Go dependency graph.
6. The AAB includes `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`, which is a massive original-name leak. The APK does not include that map.

## Scanner snapshot

For the no-VPN APK scanner run:

| Category | Match count |
| --- | ---: |
| `billing_entry_points` | 25,782 |
| `lantern_identity` | 14,267 |
| `vpn_user_strings` | 936 |
| `oauth_provider_strings` | 554 |
| `stealth_novpn_surfaces` | 356 |
| `app_links` | 299 |

Top APK locations:

| Location | Main source |
| --- | --- |
| `classes3.dex` | Stripe, Play Billing, Google Sign-In, and other third-party Android code |
| `lib/arm64-v8a/libgojni.so` | gomobile output for `lantern.io`, `github.com/getlantern/...`, `github.com/sagernet/sing-box/...`, JNI exports |
| `classes.dex` | app Kotlin package/classes and method channel names under `org.getlantern.lantern` |
| `resources.arsc` | Android resource names, mostly Stripe/billing resources |
| `lib/arm64-v8a/libapp.so` | Flutter/Dart AOT strings, package URIs, app strings, plugin names |
| `assets/flutter_assets/assets/locales/*.po` | full localization catalogs with Lantern/VPN/billing/OAuth strings |
| `assets/flutter_assets/AssetManifest.bin` | asset path names, including `vpn_*` and `lantern_*` |

For the no-VPN AAB scanner run:

| Category | Match count |
| --- | ---: |
| `billing_entry_points` | 251,736 |
| `lantern_identity` | 39,783 |
| `oauth_provider_strings` | 2,261 |
| `vpn_user_strings` | 1,252 |
| `app_links` | 747 |
| `stealth_novpn_surfaces` | 709 |

The AAB is much worse because it contains:

- `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`, size 100,015,889 bytes.
- `base/res/drawable/lantern_notification_icon.xml`.
- Signature and manifest metadata that contain file names with forbidden tokens.

## Packaged VPN/TUN/Lantern assets

The no-VPN APK contains these asset entries:

```text
assets/flutter_assets/assets/images/lantern-app-icon.icns
assets/flutter_assets/assets/images/lantern_app_icon.png
assets/flutter_assets/assets/images/lantern_chinese.svg
assets/flutter_assets/assets/images/lantern_connected.ico
assets/flutter_assets/assets/images/lantern_connected.png
assets/flutter_assets/assets/images/lantern_disconnected.ico
assets/flutter_assets/assets/images/lantern_disconnected.png
assets/flutter_assets/assets/images/lantern_logo.svg
assets/flutter_assets/assets/images/lantern_logo_round.svg
assets/flutter_assets/assets/images/lantern_pro.svg
assets/flutter_assets/assets/images/lantern_pro_chinese.svg
assets/flutter_assets/assets/images/vpn_connected.svg
assets/flutter_assets/assets/images/vpn_connecting.svg
assets/flutter_assets/assets/images/vpn_disconnected.svg
```

Source:

- `pubspec.yaml:153` includes all of `assets/images/`.
- `lib/core/common/app_image_paths.dart:2` references `assets/images/lantern_logo.svg`.
- `lib/core/common/app_image_paths.dart:19` references `assets/images/lantern_logo_round.svg`.
- `lib/core/common/app_image_paths.dart:38` references `assets/images/vpn_connected.svg`.
- `lib/core/common/app_image_paths.dart:39` references `assets/images/vpn_disconnected.svg`.
- `lib/core/common/app_image_paths.dart:40` references `assets/images/vpn_connecting.svg`.
- `lib/core/common/app_image_paths.dart:46` references `assets/images/lantern_app_icon.png`.

The AAB additionally exposes:

- `base/res/drawable/lantern_notification_icon.xml`
- Source: `android/app/src/main/res/drawable/lantern_notification_icon.xml`

Remediation: stealth/no-VPN cannot include `assets/images/` wholesale. Generate a filtered asset bundle per build profile, or copy profile-safe assets into a generated directory and point the stealth build at that directory. Rename neutral assets at source or in post-processing before Flutter builds `AssetManifest.bin`.

## Packaged localization strings

`pubspec.yaml:160` includes all of `assets/locales/`. These `.po` files are packaged verbatim into the APK and include both msgids and msgstrs. Runtime UI gating does not remove them from the artifact.

Examples from `assets/locales/en.po`:

- `assets/locales/en.po:64` contains `VPN Settings`.
- `assets/locales/en.po:99` contains `split_tunneling`.
- `assets/locales/en.po:166` contains `VPN Status`.
- `assets/locales/en.po:373` describes bypassing the VPN.
- `assets/locales/en.po:400` contains `Continue with Google`.
- `assets/locales/en.po:403` contains `Continue with Apple`.
- `assets/locales/en.po:482` contains `stripe_payment`.
- `assets/locales/en.po:575` contains `vpn_connected`.
- `assets/locales/en.po:578` contains `vpn_disconnected`.
- `assets/locales/en.po:608` contains `next_billing_date`.
- `assets/locales/en.po:741` contains `billing_account`.
- `assets/locales/en.po:1308` contains `add_billing_details`.
- `assets/locales/en.po:1612` warns that another VPN is running.

Remediation: produce stealth/no-VPN locale catalogs at build time. They must remove unused msgids/msgstrs/comments and replace product naming with the selected stealth profile. Keeping the same `.po` files and hiding UI branches is not enough.

## Android/Kotlin identity and VPN strings

`android/app/build.gradle` randomizes the runtime application ID, but the compiled namespace is still fixed:

- `android/app/build.gradle:176` sets `applicationId` from the stealth profile.
- `android/app/build.gradle:251` sets `namespace = "org.getlantern.lantern"`.
- `android/app/build.gradle:421` adds `proguard-stealth-novpn.pro`.

That means app code still compiles under `org.getlantern.lantern`. R8 may rename some implementation details, but enough package/class/method/string names remain in `classes.dex`.

Main sources:

- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:7` imports `android.net.VpnService`.
- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:25` imports `LanternVpnService`.
- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:27` imports `QuickTileService`.
- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:198` defines `startVPN()`.
- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:270` defines `stopVPN()`.
- `android/app/src/main/kotlin/org/getlantern/lantern/MainActivity.kt:307` defines `isVPNServiceReady()`.
- `android/app/src/main/kotlin/org/getlantern/lantern/constant/VPNStatus.kt:3` defines `VPNStatus`.
- `android/app/src/main/kotlin/org/getlantern/lantern/utils/VpnStatusManager.kt` and `android/app/src/main/kotlin/org/getlantern/lantern/utils/VPNStatusRecevier.kt` keep VPN class names and log strings.

The stealth bridge wrappers are not enough because they subclass original classes. In the decompiled APK:

- `foundation/bridge/AppHost.smali` extends `org/getlantern/lantern/LanternApp`.
- `foundation/bridge/HomeActivity.smali` extends `org/getlantern/lantern/MainActivity`.
- `foundation/bridge/SyncService.smali` extends `org/getlantern/lantern/service/NoVpnLanternService`.

Remediation: the no-VPN build needs a different compile-time Android surface, not only a different manifest. Options:

1. Move shared Android code behind neutral interfaces and compile stealth/no-VPN source sets with neutral package/class names.
2. Ensure no-VPN does not compile `LanternVpnService`, `QuickTileService`, `VpnService` imports, `VPNStatusReceiver`, or VPN-named method APIs.
3. Add R8 verification with `-checkdiscard` for all forbidden classes, not just the VPN service.
4. Treat package namespace as part of stealth identity. Randomizing `applicationId` alone is insufficient.

## no-VPN service still imports TUN/VPN abstractions

`NoVpnLanternService` is intended to be the no-VPN path, but it still exposes TUN/VPN identifiers:

- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:24` imports `lantern.io.libbox.TunOptions`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:30` imports `VPNStatus`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:34` imports `VpnStatusManager`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:44` uses action string `org.getlantern.START_LOCAL_PROXY`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:45` uses action string `org.getlantern.LOCAL_PROXY_CONNECT_TO_SERVER`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:46` uses action string `org.getlantern.STOP_LOCAL_PROXY`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:102` calls `Mobile.startVPN()`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:131` calls `Mobile.stopVPN()`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:234` defines `openTun(tunOptions: TunOptions)`.
- `android/app/src/main/kotlin/org/getlantern/lantern/service/NoVpnLanternService.kt:235` contains `TUN is disabled in stealth no-VPN builds`.

Remediation: no-VPN needs a proxy-specific Android service and Go/mobile API. It should not import libbox `TunOptions`, implement `openTun`, call `Mobile.startVPN`, call `Mobile.stopVPN`, or post `VPNStatus`. Use neutral names such as connection/proxy status at the Dart and Android boundary.

## Method channels and Dart API names

The method channel and Dart service APIs retain original names. These strings are present in Dart AOT (`libapp.so`) and Android DEX.

Android source:

- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:41` has `Start("startVPN")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:42` has `Stop("stopVPN")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:44` has `IsVpnConnected("isVPNConnected")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:48` has `StripeSubscription("stripeSubscription")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:49` has `StripeBillingPortal("stripeBillingPortal")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:58` has `OAuthLoginUrl("oauthLoginUrl")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:59` has `OAuthLoginCallback("oauthLoginCallback")`.
- `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt:159` has channel name `org.getlantern.lantern/method`.

Dart source:

- `lib/lantern/lantern_platform_service.dart:33` has `channelPrefix = 'org.getlantern.lantern'`.
- `lib/lantern/lantern_platform_service.dart:136` invokes `startVPN`.
- `lib/lantern/lantern_platform_service.dart:185` invokes `stopVPN`.
- `lib/lantern/lantern_platform_service.dart:195` exposes `watchVPNStatus()`.
- `lib/lantern/lantern_platform_service.dart:245` invokes `isVPNConnected`.
- `lib/lantern/lantern_platform_service.dart:668` invokes `stripeSubscriptionPaymentRedirect`.
- `lib/lantern/lantern_platform_service.dart:699` invokes `stripeSubscription`.
- `lib/lantern/lantern_platform_service.dart:718` invokes `stripeBillingPortal`.
- `lib/lantern/lantern_platform_service.dart:865` invokes `oauthLoginUrl`.
- `lib/lantern/lantern_platform_service.dart:885` invokes `oauthLoginCallback`.
- `lib/lantern/lantern_generated_bindings.dart:5618` through `lib/lantern/lantern_generated_bindings.dart:5774` bind exported FFI symbols named `startVPN`, `stopVPN`, `isVPNConnected`, `stripeSubscriptionPaymentRedirect`, `stripeBillingPortalUrl`, and `oauthLoginUrl`.

Remediation: stealth/no-VPN needs a neutral method-channel contract and a generated binding surface that excludes forbidden APIs. Conditional runtime checks do not remove strings from AOT or DEX.

## Stripe, Play Billing, Google Sign-In, and OAuth

The build flags hide some UI and manifest entry points, but the dependencies still exist in the build graph.

Dependency sources:

- `pubspec.yaml:26` pins `in_app_purchase_storekit`.
- `pubspec.yaml:27` pins `in_app_purchase_android`.
- `pubspec.yaml:109` depends on `in_app_purchase`.
- `pubspec.yaml:110` depends on `flutter_stripe`.
- `lib/core/services/app_purchase.dart:4` imports `in_app_purchase`.
- `lib/core/services/app_purchase.dart:5` imports `in_app_purchase_android`.
- `lib/core/services/stripe_service.dart:3` imports `flutter_stripe`.
- `lib/features/auth/choose_payment_method.dart:5` imports `flutter_stripe`.
- `lib/features/plans/plans.dart:7` imports `in_app_purchase`.
- `lib/features/plans/restore_purchase_mixin.dart:2` imports `in_app_purchase`.

Packaged evidence from the decompiled APK:

- `/tmp/lantern-novpn-apktool-20260518/smali/com/stripe/...`
- `/tmp/lantern-novpn-apktool-20260518/smali/com/flutter/stripe/...`
- `/tmp/lantern-novpn-apktool-20260518/smali/com/reactnativestripesdk/...`
- `/tmp/lantern-novpn-apktool-20260518/unknown/billing.properties:2` contains `client=billing`.
- `/tmp/lantern-novpn-apktool-20260518/unknown/billing.properties:3` contains `billing_client=7.1.1`.
- `/tmp/lantern-novpn-apktool-20260518/unknown/lpms.json` contains many `billing_details[...]` entries and `https://js.stripe.com/...` URLs.
- `/tmp/lantern-novpn-apktool-20260518/res/drawable/stripe_*`, `/tmp/lantern-novpn-apktool-20260518/res/layout/stripe_*`, and related Stripe resources are present.

Remediation: remove these packages from stealth/no-VPN dependency resolution, not only from UI. Flutter does not support feature-eliding plugins just because code paths are gated. Practical options are:

1. Generate a stealth-specific `pubspec.yaml` or dependency override before `flutter pub get`.
2. Move payment/OAuth UI and service code behind conditional imports where the disabled implementation does not import the packages.
3. Generate a stealth-safe plugin registrant and Android dependency graph.
4. Add artifact assertions that `com/stripe`, `com/flutter/stripe`, `com/android/billingclient`, `billing.properties`, `lpms.json`, and Google Sign-In classes are absent.

## Go/gomobile/native leaks

`libgojni.so` remains one of the largest sources.

Build source:

- `Makefile:185` through `Makefile:188` sets `GOMOBILE_REPOS` to include `github.com/sagernet/sing-box/experimental/libbox`, `./lantern-core/mobile`, and `./lantern-core/utils`.
- `Makefile:194` sets `GARBLE_GOGARBLE ?= github.com/getlantern/lantern`.
- `Makefile:729` through `Makefile:736` build Android gomobile with `-javapkg=lantern.io`.
- `Makefile:755` through `Makefile:764` do the same for the garbled Android path.

Source APIs:

- `lantern-core/ffi/ffi.go:169` exports `isOAuthLogin`.
- `lantern-core/ffi/ffi.go:178` exports `getOAuthProvider`.
- `lantern-core/ffi/ffi.go:531` exports `startVPN`.
- `lantern-core/ffi/ffi.go:552` exports `stopVPN`.
- `lantern-core/ffi/ffi.go:591` exports `isVPNConnected`.
- `lantern-core/ffi/ffi.go:647` exports `stripeSubscriptionPaymentRedirect`.
- `lantern-core/ffi/ffi.go:689` exports `stripeBillingPortalUrl`.
- `lantern-core/ffi/ffi.go:723` exports `oauthLoginUrl`.
- `lantern-core/mobile/mobile.go` imports `github.com/getlantern/radiance/...` and exposes mobile OAuth, Stripe, VPN, split-tunnel, private-server, and account APIs.
- `lantern-core/core.go:17` through `lantern-core/core.go:30` imports `github.com/getlantern/radiance/...`, `github.com/getlantern/lantern/...`, and `vpn_tunnel`.
- `lantern-core/core.go:773` through `lantern-core/core.go:927` implements OAuth, Stripe, Google/Apple purchase, and payment redirect methods.

Exported symbols confirmed with `readelf -Ws /tmp/lantern-novpn-apktool-20260518/lib/arm64-v8a/libgojni.so`:

- `Java_lantern_io_mobile_Mobile_startVPN`
- `Java_lantern_io_mobile_Mobile_stopVPN`
- `Java_lantern_io_mobile_Mobile_isVPNConnected`
- `Java_lantern_io_mobile_Mobile_stripeSubscription`
- `Java_lantern_io_mobile_Mobile_stripeSubscriptionPaymentRedirect`
- `Java_lantern_io_mobile_Mobile_stripeBillingPortalUrl`
- `Java_lantern_io_libbox_Libbox_readAndroidVPNType`
- many `Java_lantern_io_libbox_Libbox_$proxyTunOptions_*` symbols

This is not only a `strings` problem. Some identifiers are exported dynamic symbols required by the gomobile Java interface. Garble cannot safely rename those after the Java/Kotlin side depends on them.

Remediation:

1. Build a no-VPN gomobile artifact with a reduced Go package/API surface. It should not bind libbox TUN/VPN APIs or mobile methods named VPN/OAuth/Stripe/Billing.
2. Use Go build tags to exclude OAuth, billing, payment, private server, VPN, TUN, and split-tunnel code from the no-VPN native artifact.
3. Use a neutral `-javapkg` for stealth/no-VPN builds.
4. Extend `GOGARBLE` beyond `github.com/getlantern/lantern` if those dependencies must remain, but do not expect garble to hide exported JNI method names.
5. Add `readelf` and `strings` assertions for `Java_lantern_io_*`, `TunOptions`, `AndroidVPNType`, `github.com/getlantern`, `github.com/sagernet`, `stripe`, `oauth`, and `billing`.

## App links and Lantern URLs

The final decompiled no-VPN APK manifest did not show the old `lantern.io` app-link filters, but app-link and Lantern URLs still appear elsewhere.

Sources:

- `lib/lantern_app.dart:107` handles `/report-issue`.
- `lib/lantern_app.dart:128` handles `/auth`.
- `lib/lantern_app.dart:132` handles `/private-server`.
- `lib/lantern_app.dart:188` checks `lantern.io` and `www.lantern.io`.
- `lib/core/common/app_urls.dart:4` defines `https://lantern.io`.
- `lib/core/common/app_urls.dart:5` defines `https://support.lantern.io`.
- `lib/core/common/app_urls.dart:17` defines `https://github.com/getlantern/lantern`.
- `lib/core/common/app_urls.dart:21` defines `https://unbounded.lantern.io`.
- `lib/core/common/app_urls.dart:23` defines `https://github.com/getlantern/lantern-server-manager`.
- `lib/core/common/app_urls.dart:33` through `lib/core/common/app_urls.dart:37` define `s3.amazonaws.com/lantern.io/.../appcast.xml`.
- `lib/core/common/app_urls.dart:42` checks `lantern.io` and `www.lantern.io`.
- `lib/core/widgets/app_webview.dart:217` handles `/auth`.

There are stale source manifest entries in `android/app/src/main/AndroidManifest.novpn.xml:52` through `android/app/src/main/AndroidManifest.novpn.xml:101`, but the decompiled final no-VPN manifest did not include those lines. Treat them as a reintroduction risk, not as the current APK manifest source.

Remediation: stealth/no-VPN needs neutral URLs or no app-link handling in compiled Dart/Android code. Build flags must remove the code and strings from the artifact, not only disable navigation.

## AAB-specific metadata leak

The no-VPN AAB contains:

```text
BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map
```

Size: 100,015,889 bytes.

This file contains original class/resource mappings. It explains the much higher AAB scanner count and makes the AAB unsuitable as a stealth-distributed artifact unless this metadata is stripped or never shipped to users.

Remediation:

1. Do not distribute stealth/no-VPN AABs directly to users.
2. Strip `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map` from stealth AAB outputs if an AAB must be produced.
3. Prefer APK distribution for stealth/no-VPN until the AAB pipeline has a separate artifact-sanitization step.
4. Add a CI assertion that stealth/no-VPN AABs do not contain `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`.

## Likely false positive

The scanner found one `TUN` token in `libflutter.so`. The excerpt looks like ICU/locale data rather than an app VPN/TUN surface. Keep this as an allowlist candidate only after the real app and dependency leaks are removed.

Do not broaden the allowlist now. The current artifact has many real VPN/TUN sources.

## Priority remediation plan

P0: stop packaging unsafe Flutter assets and locales.

- Generate stealth/no-VPN asset and locale directories before build.
- Exclude `assets/images/vpn_*`, `assets/images/lantern_*`, and full `.po` catalogs with forbidden strings.
- Verify `AssetManifest.bin` and APK entry names.

P0: remove payment/OAuth dependencies from stealth/no-VPN dependency graphs.

- Use generated pubspec/dependency overrides or conditional packages.
- Ensure no `flutter_stripe`, `in_app_purchase`, Play Billing, Google Sign-In, Stripe resources, `billing.properties`, or `lpms.json` remain.

P0: create a reduced no-VPN Go/gomobile API.

- Exclude TUN/VPN/OAuth/Billing APIs by Go build tag.
- Use neutral exported API names and neutral `-javapkg`.
- Do not bind `github.com/sagernet/sing-box/experimental/libbox` if the no-VPN build only needs a SOCKS proxy API.

P0: replace the Android/Kotlin no-VPN surface.

- Compile no-VPN without `LanternVpnService`, `QuickTileService`, `VpnService`, `VPNStatus`, `VpnStatusManager`, `VPNStatusReceiver`, and VPN-named methods.
- Use neutral source-set classes instead of bridge wrappers extending original classes.
- Make `namespace` profile-specific or ensure R8 relocation/obfuscation is verified in the artifact.

P1: neutralize Dart method channels and service names.

- Replace `org.getlantern.lantern` method/event channels for stealth/no-VPN.
- Replace `startVPN`, `stopVPN`, `watchVPNStatus`, and `isVPNConnected` with neutral names in the compiled no-VPN interface.

P1: strip or block unsafe AAB metadata.

- Strip `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`.
- Add an AAB scanner gate separate from the APK gate.

P1: tighten leakage CI.

- Scan APK and AAB zip entry names, DEX strings, `libapp.so`, `libgojni.so`, `resources.arsc`/`resources.pb`, Flutter assets, and localization files.
- Add `readelf -Ws` checks for exported native symbols.
- Add targeted `-checkdiscard` rules for forbidden Android classes.

## Bottom line

The current no-VPN build proves the manifest can be changed, but it does not yet meet the stealth requirement. The next implementation pass has to change what enters the build graph: assets, locales, Flutter plugins, Android source sets, gomobile bindings, and AAB metadata. Post-processing alone can help with package/app identity and final artifact assertions, but it will not remove these leaks while the forbidden code and resources are still compiled or packaged.
