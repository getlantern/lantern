import 'dart:io';

class PlatformUtils{
 static bool isDesktop() {
    return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  }

 static bool isIOS() {
   return Platform.isIOS;
 }

 static bool isAndroid() {
   return Platform.isAndroid;
 }
}