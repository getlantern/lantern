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
}

Future<String> resolveAppVersionLabel() async {
  /// Since now we are injecting the version and build number at compile time,
  /// we can directly use those values instead of fetching them from the platform.
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
