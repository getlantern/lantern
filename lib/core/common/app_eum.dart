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

enum SplitTunnelingMode {
  automatic,
  manual;

  String get value {
    switch (this) {
      case SplitTunnelingMode.automatic:
        return 'automatic';
      case SplitTunnelingMode.manual:
        return 'manual';
    }
  }
}

extension SplitTunnelingModeString on String {
  SplitTunnelingMode get toSplitTunnelingMode {
    switch (this) {
      case 'Automatic':
        return SplitTunnelingMode.automatic;
      case 'Manual':
        return SplitTunnelingMode.manual;
      default:
        return SplitTunnelingMode.automatic;
    }
  }
}

enum BypassListOption {
  global,
  russia,
  china,
  iran;

  String get value {
    switch (this) {
      case BypassListOption.russia:
        return 'russia';
      case BypassListOption.china:
        return 'china';
      case BypassListOption.iran:
        return 'iran';
      case BypassListOption.global:
        return 'global';
    }
  }
}

extension BypassListOptionString on String {
  BypassListOption get toBypassList {
    switch (this) {
      case 'russia':
        return BypassListOption.russia;
      case 'china':
        return BypassListOption.china;
      case 'iran':
        return BypassListOption.iran;
      default:
        return BypassListOption.global;
    }
  }
}
