import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

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

  /// Lets a test act as a desktop or not, whatever its host.
  @visibleForTesting
  static bool? debugIsDesktop;

  static bool get isDesktop =>
      debugIsDesktop ??
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Lets a test play a macOS host on another platform.
  static bool? debugIsMacOS;

  static bool get isMacOS => debugIsMacOS ?? Platform.isMacOS;

  static bool get isWindows => Platform.isWindows;

  static bool get isLinux => Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static bool get isIOS {
    return Platform.isIOS;
  }

  static bool get isAndroid {
    return Platform.isAndroid;
  }

  static bool get supportsSplitTunneling =>
      Platform.isAndroid || Platform.isMacOS || Platform.isWindows;

  static bool get isFFISupported {
    return Platform.isWindows || Platform.isLinux;
  }
}
