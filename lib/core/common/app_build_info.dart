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

  static bool get isStealthBuild

=> stealthMode.startsWith('stealth-');

  static const bool stealthBuild = bool.fromEnvironment(
    'STEALTH_BUILD',
    defaultValue: false,
  );

  static const String stealthModeName = String.fromEnvironment(
    'STEALTH_MODE',
    defaultValue: '',
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

  static const String appAuthScheme = String.fromEnvironment(
    'APP_AUTH_SCHEME',
    defaultValue: 'lantern',
  );

  static bool isAppAuthUri(Uri uri)

{
    return uri.scheme == appAuthScheme;
  }

  /// Developer mode is exposed in debug and nightly builds only.
  static bool get isDevModeEnabled => kDebugMode || buildType == 'nightly';
}

///Always use values from app build info this will ensure that the version and build number are same
Future<String> resolveAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
