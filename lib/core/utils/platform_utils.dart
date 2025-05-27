import 'dart:io';

class PlatformUtils {
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static bool get isMacOS =>
      Platform.isMacOS ;

  static bool get isMobile =>
      Platform.isAndroid || Platform.isIOS;

  static bool get isIOS{
    return Platform.isIOS;
  }
  static bool get isAndroid {
    return Platform.isAndroid;
  }
}
