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
  static const directDownloadWindows =
      '$_s3ReleasesLatest/lantern-installer.exe';
  static const directDownloadMac = '$_s3ReleasesLatest/lantern-installer.dmg';
  static const updateServiceLantern =
      'https://update.getlantern.org/update/lantern';
  static const appcastProd = '$updateServiceLantern/appcast.xml?channel=stable';
  static const appcastBeta = '$updateServiceLantern/appcast.xml?channel=beta';
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
  }) {
    if (autoUpdateE2E) return appcastE2E;
    switch (buildType) {
      case 'production':
        return appcastProd;
      case 'beta':
        return appcastBeta;
      default:
        return appcastProd;
    }
  }
}
