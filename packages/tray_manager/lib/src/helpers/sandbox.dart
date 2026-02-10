import 'dart:io';

/// Returns `true` if the app is running in a sandbox, eg. Flatpak, Snap, Docker, Podman.
bool runningInSandbox() {
  return Platform.environment.containsKey('FLATPAK_ID') ||
      Platform.environment.containsKey('SNAP') ||
      (Platform.environment['container']?.isNotEmpty == true) ||
      FileSystemEntity.isFileSync('/.dockerenv');
}
