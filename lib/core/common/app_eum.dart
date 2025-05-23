enum VPNStatus {
  connected,
  disconnected,
  connecting,
  disconnecting,
  missingPermission,
  error,
}

enum AuthFlow { resetPassword, signUp, activationCode }

enum AppFlow {
  store,
  nonStore,
}

enum StipeSubscriptionType { monthly, yearly, one_time }

enum SplitTunnelFilterType {
  domain,
  domainSuffix,
  domainKeyword,
  domainRegex,
  processName,
  packageName;

  String get value {
    switch (this) {
      case SplitTunnelFilterType.domain:
        return 'domain';
      case SplitTunnelFilterType.domainSuffix:
        return 'domainSuffix';
      case SplitTunnelFilterType.domainKeyword:
        return 'domainKeyword';
      case SplitTunnelFilterType.domainRegex:
        return 'domainRegex';
      case SplitTunnelFilterType.processName:
        return 'processName';
      case SplitTunnelFilterType.packageName:
        return 'packageName';
    }
  }
}

enum SplitTunnelActionType {
  add,
  remove;

  String get value {
    switch (this) {
      case SplitTunnelActionType.add:
        return 'add';
      case SplitTunnelActionType.remove:
        return 'remove';
    }
  }
}

enum BypassListOption { global, russia, china, iran }

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
