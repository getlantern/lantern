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
