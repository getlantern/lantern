import 'dart:io';

class PlatformUtils {
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
