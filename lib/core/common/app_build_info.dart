import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppBuildInfo {
  static const String buildType = String.fromEnvironment(
    'BUILD_TYPE',
    defaultValue: 'production',
  );

  static const String version = String.fromEnvironment(
    'VERSION',
    defaultValue: '',
  );

  static const bool disableSystemTray = bool.fromEnvironment(
    'DISABLE_SYSTEM_TRAY',
    defaultValue: false,
  );

  static const bool autoUpdateE2E = bool.fromEnvironment(
    'AUTO_UPDATE_E2E',
    defaultValue: false,
  );

  static const String stealthMode = String.fromEnvironment(
    'STEALTH_MODE',
    defaultValue: 'normal',
  );

  static const bool stealthNoVpn = bool.fromEnvironment(
    'STEALTH_NO_VPN',
    defaultValue: false,
  );

  static const String stealthPackageName = String.fromEnvironment(
    'STEALTH_PACKAGE_NAME',
    defaultValue: 'org.getlantern.lantern',
  );

  static const String stealthAppName = String.fromEnvironment(
    'STEALTH_APP_NAME',
    defaultValue: 'Lantern',
  );

  static const String stealthSessionName = String.fromEnvironment(
    'STEALTH_SESSION_NAME',
    defaultValue: 'LanternVpn',
  );

  static const int stealthDenylistVersion = int.fromEnvironment(
    'STEALTH_DENYLIST_VERSION',
    defaultValue: 0,
  );

  static bool get isStealthBuild =>
      stealthBuild ||
      stealthNoVpn ||
      stealthMode.startsWith('stealth-') ||
      stealthMode == 'true';

  static const bool stealthBuild = bool.fromEnvironment(
    'STEALTH_BUILD',
    defaultValue: false,
  );

  /// Removes high-identification UI and runtime flows from stealth artifacts.
  static const bool suppressIdentifyingFeatures =
      stealthBuild ||
      stealthNoVpn ||
      stealthMode == 'stealth-vpn' ||
      stealthMode == 'stealth-novpn' ||
      stealthMode == 'true';

  static const bool enableOAuth = !suppressIdentifyingFeatures;

  static const bool enableAppLinks = !suppressIdentifyingFeatures;

  static const bool enableSocialLinks = !suppressIdentifyingFeatures;

  static const bool enableAutoUpdate = !suppressIdentifyingFeatures;

  static const String appAuthScheme = String.fromEnvironment(
    'APP_AUTH_SCHEME',
    defaultValue: 'lantern',
  );

  static bool isAppAuthUri(Uri uri) {
    return uri.scheme == appAuthScheme;
  }

  static const bool stealthDirectConnectionApps = bool.fromEnvironment(
    'STEALTH_DIRECT_CONNECTION_APPS',
    defaultValue: false,
  );

  /// Developer mode is exposed in debug and nightly builds only.
  static bool get isDevModeEnabled => kDebugMode || buildType == 'nightly';
}

///Always use values from app build info this will ensure that the version and build number are same
Future<String> resolveAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
