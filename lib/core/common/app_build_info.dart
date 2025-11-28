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
  if (AppBuildInfo.version.isNotEmpty) return AppBuildInfo.version;

  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
