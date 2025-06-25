enum VPNStatus {
  connected,
  disconnected,
  connecting,
  disconnecting,
  missingPermission,
  error,
}

enum AuthFlow { resetPassword, oauth, signUp, activationCode }

enum BillingType { subscription, one_time }

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
