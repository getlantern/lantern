import 'dart:io';

class PlatformUtils{
 static bool isDesktop() {
    return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }
}