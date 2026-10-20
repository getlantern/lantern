import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class PlatformUtils {
  /// Android TV / Google TV (leanback). Set once at startup by [initDeviceType].
  static bool isTv = false;

  static Future<void> initDeviceType() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      isTv = info.systemFeatures.contains('android.software.leanback');
    } catch (_) {
      isTv = false;
    }
  }

  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isLinux => Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isIOS {
    return Platform.isIOS;
  }

  static bool get isAndroid {
    return Platform.isAndroid;
  }

  static bool get isFFISupported {
    return Platform.isWindows || Platform.isLinux;
  }
}
