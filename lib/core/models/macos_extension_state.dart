enum SystemExtensionStatus {
  notInstalled,
  installed,
  requiresApproval,
  timedOut,
  activated,
  deactivated,
  uninstalling,
  error,
  unknown,
}

class MacOSExtensionState {
  final SystemExtensionStatus status;
  final String? message;

  const MacOSExtensionState(this.status, [this.message]);

  factory MacOSExtensionState.fromString(String raw) {
    if (raw.startsWith("error:")) {
      return MacOSExtensionState(SystemExtensionStatus.error, raw.substring(6));
    }


    switch (raw) {
      case 'notInstalled':
        return const MacOSExtensionState(SystemExtensionStatus.notInstalled);
      case 'installed':
        return const MacOSExtensionState(SystemExtensionStatus.installed);
      case 'requiresApproval':
        return const MacOSExtensionState(SystemExtensionStatus.requiresApproval);
      case 'timedOut':
        return const MacOSExtensionState(SystemExtensionStatus.timedOut);
      case 'activated':
        return const MacOSExtensionState(SystemExtensionStatus.activated);
      case 'deactivated':
        return const MacOSExtensionState(SystemExtensionStatus.deactivated);
      case 'uninstalling':
        return const MacOSExtensionState(SystemExtensionStatus.uninstalling);
      default:
        return const MacOSExtensionState(SystemExtensionStatus.unknown);
    }
  }
}
