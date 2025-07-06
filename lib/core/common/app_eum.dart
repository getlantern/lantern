enum VPNStatus {
  connected,
  disconnected,
  connecting,
  disconnecting,
  missingPermission,
  error,
}

enum ServerLocationType {
  auto,
  privateServer,
  lanternLocation;
}

extension ServerLocationTypeExtension on String {
  ServerLocationType get toServerLocationType {
    switch (this) {
      case 'auto':
        return ServerLocationType.auto;
      case 'privateServer':
        return ServerLocationType.privateServer;
      case 'lanternLocation':
        return ServerLocationType.lanternLocation;
      default:
        return ServerLocationType.auto;
    }
  }
}

enum AuthFlow { resetPassword, oauth, signUp, activationCode }

enum BillingType { subscription, one_time }

enum PrivateServerInput { selectAccount, selectProject }

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
    switch (toLowerCase()) {
      case 'automatic':
        return SplitTunnelingMode.automatic;
      case 'manual':
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

enum CloudProvider {
  googleCloud,
  digitalOcean;

  String get value {
    switch (this) {
      case CloudProvider.googleCloud:
        return 'gcp';
      case CloudProvider.digitalOcean:
        return 'do';
    }
  }

  String get displayName {
    switch (this) {
      case CloudProvider.googleCloud:
        return "Google";
      case CloudProvider.digitalOcean:
        return "Digital Ocean";
    }
  }
}
