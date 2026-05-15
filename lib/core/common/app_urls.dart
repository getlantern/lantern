import 'package:lantern/core/common/app_build_info.dart';

class AppUrls {
  static String lanternOfficial = 'https://lantern.io';
  static String support = 'https://support.lantern.io';
  static String get lanternForums =>
      AppBuildInfo.enableSocialLinks ? 'https://lantern.io/forums' : '';
  static String faq = '$lanternOfficial/faq';
  static String privacyPolicy = '$lanternOfficial/privacy';
  static String termsOfService = '$lanternOfficial/terms';
  static String downloadAndroid = '$lanternOfficial/download?os=android';
  static String downloadWindows = '$lanternOfficial/download?os=windows';
  static String downloadIos = '$lanternOfficial/download?os=ios';
  static String downloadMac = '$lanternOfficial/download?os=mac';
  static String downloadLinux = '$lanternOfficial/download?os=linux';
  static String get lanternGithub => AppBuildInfo.enableSocialLinks
      ? 'https://github.com/getlantern/lantern'
      : '';
  static String get telegramBot =>
      AppBuildInfo.enableSocialLinks ? 'https://t.me/lantern_official_bot' : '';
  static String unbounded = 'https://unbounded.lantern.io';
  static String manuallyServerSetupURL =
      'https://github.com/getlantern/lantern-server-manager';
  static String digitalOceanBillingUrl =
      'https://cloud.digitalocean.com/account/billing';
  static String androidSideloadUpdateEndpoint =
      'https://update.getlantern.org/update/lantern';

  static String? appcastFor(String buildType) {
    if (!AppBuildInfo.enableAutoUpdate) {
      return null;
    }
    switch (buildType) {
      case 'production':
        return 'https://s3.amazonaws.com/lantern.io/releases/production/latest/appcast.xml';
      case 'beta':
        return 'https://s3.amazonaws.com/lantern.io/releases/beta/latest/appcast.xml';
      default:
        return 'https://s3.amazonaws.com/lantern.io/releases/production/latest/appcast.xml';
    }
  }

  static bool isLanternHost(String host) =>
      host == 'lantern.io' || host == 'www.lantern.io';
}
