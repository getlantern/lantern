import 'dart:io';

bool isDesktop() {
  return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
}
