enum SplitTunnelingMode { automatic, manual }

extension SplitTunnelingModeExtension on SplitTunnelingMode {
  String get displayName {
    switch (this) {
      case SplitTunnelingMode.automatic:
        return "Automatic";
      case SplitTunnelingMode.manual:
        return "Manual";
    }
  }
}
