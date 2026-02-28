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
}

///Always use values from app build info this will ensure that the version and build number are same
Future<String> resolveAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
