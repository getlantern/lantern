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

  static const bool stealthBuild = bool.fromEnvironment(
    'STEALTH_BUILD',
    defaultValue: false,
  );

  static const String stealthModeName = String.fromEnvironment(
    'STEALTH_MODE',
    defaultValue: '',
  );

  static const bool stealthNoVpn = bool.fromEnvironment(
    'STEALTH_NO_VPN',
    defaultValue: false,
  );

  /// Removes high-identification UI and runtime flows from stealth artifacts.
  static const bool stealthMode =
      stealthBuild ||
      stealthNoVpn ||
      stealthModeName == 'stealth-vpn' ||
      stealthModeName == 'stealth-novpn' ||
      stealthModeName == 'true';

  static const bool enableOAuth = !stealthMode;
  static const bool enablePayments = !stealthMode;
  static const bool enableStorePayments = !stealthMode;
  static const bool enableAppLinks = !stealthMode;
  static const bool enableSocialLinks = !stealthMode;
  static const bool enableAutoUpdate = !stealthMode;

  /// Developer mode is exposed in debug and nightly builds only.
  static bool get isDevModeEnabled => kDebugMode || buildType == 'nightly';
}

///Always use values from app build info this will ensure that the version and build number are same
Future<String> resolveAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
