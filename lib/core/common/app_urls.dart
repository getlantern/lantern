import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_build_info.dart';

class AppUrls {
  static String lanternOfficial = 'https://lantern.io';
  static String support = 'https://support.lantern.io';
  static String lanternForums = 'https://lantern.io/forums';
  static String faq = '$lanternOfficial/faq';
  static String privacyPolicy = '$lanternOfficial/privacy';
  static String termsOfService = '$lanternOfficial/terms';
  static String downloadAndroid = '$lanternOfficial/download?os=android';
  static String downloadWindows = '$lanternOfficial/download?os=windows';
  static String downloadIos = '$lanternOfficial/download?os=ios';
  static String downloadMac = '$lanternOfficial/download?os=mac';
  static String downloadLinux = '$lanternOfficial/download?os=linux';
  static String lanternGithub = 'https://github.com/getlantern/lantern';
  static String telegramBot = 'https://t.me/lantern_official_bot';
  static String unbounded = 'https://unbounded.lantern.io';
  // Direct installer links published by the release workflow
  // (scripts/ci/publish-to-s3.sh uploads to releases/{build_type}/latest/).
  static const _s3ReleasesLatest =
      'https://s3.amazonaws.com/lantern.io/releases/production/latest';
  static const directDownloadAndroid =
      '$_s3ReleasesLatest/lantern-installer.apk';
  static const directDownloadAndroidArmv7 =
      '$_s3ReleasesLatest/lantern-installer-armv7.apk';
  static const directDownloadWindows =
      '$_s3ReleasesLatest/lantern-installer.exe';
  static const directDownloadMac = '$_s3ReleasesLatest/lantern-installer.dmg';
  static const updateServiceLantern =
      'https://update.getlantern.org/update/lantern';
  static const appcastE2E =
      'https://update.staging.iantem.io/update/lantern/appcast.xml?channel=beta';
  static String manuallyServerSetupURL =
      'https://github.com/getlantern/lantern-server-manager';
  static String digitalOceanBillingUrl =
      'https://cloud.digitalocean.com/account/billing';
  static const androidSideloadUpdateEndpoint = updateServiceLantern;

  static String appcastFor(
    String buildType, {
    bool autoUpdateE2E = AppBuildInfo.autoUpdateE2E,
    TargetPlatform? platform,
  }) {
    if (autoUpdateE2E) return appcastE2E;
    final channel = UpdateChannel.forBuildType(buildType);
    final url = '$updateServiceLantern/appcast.xml?channel=${channel.name}';
    // Nightly feeds are signed per platform, so the server needs to know which.
    if (channel != UpdateChannel.nightly) return url;
    final target = platform ?? defaultTargetPlatform;
    return '$url&platform=${target.name.toLowerCase()}';
  }
}

/// Desktop update feed channels, named as the update server's `channel` values.
enum UpdateChannel {
  stable,
  beta,
  nightly;

  /// Unknown build types get the stable feed.
  static UpdateChannel forBuildType(String buildType) => switch (buildType) {
    'beta' => beta,
    'nightly' => nightly,
    _ => stable,
  };
}
