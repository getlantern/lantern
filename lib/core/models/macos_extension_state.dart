enum SystemExtensionStatus {
  notInstalled,
  installed,
  requiresApproval,
  requiresReboot,
  updatePending,
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

  bool get isReady =>
      status == SystemExtensionStatus.installed ||
      status == SystemExtensionStatus.activated;

  factory MacOSExtensionState.fromEvent(Object? event) {
    if (event is Map) {
      return _fromStatusFields(
        _stringField(event, 'status'),
        _stringField(event, 'details'),
      );
    }

    if (event is String) {
      return MacOSExtensionState.fromString(event);
    }

    if (event == null) {
      return const MacOSExtensionState(SystemExtensionStatus.unknown);
    }

    return MacOSExtensionState.fromString(event.toString());
  }

  factory MacOSExtensionState.fromString(String raw) {
    if (raw.startsWith('error:')) {
      return MacOSExtensionState(SystemExtensionStatus.error, raw.substring(6));
    }

    if (raw.startsWith('updatePending:')) {
      return MacOSExtensionState(
        SystemExtensionStatus.updatePending,
        raw.substring('updatePending:'.length),
      );
    }

    if (raw.startsWith('requiresReboot:')) {
      return MacOSExtensionState(
        SystemExtensionStatus.requiresReboot,
        raw.substring('requiresReboot:'.length),
      );
    }

    return _fromStatusFields(raw, null);
  }

  static MacOSExtensionState _fromStatusFields(
    String? status,
    String? details,
  ) {
    switch (status) {
      case 'notInstalled':
        return const MacOSExtensionState(SystemExtensionStatus.notInstalled);
      case 'installed':
        return const MacOSExtensionState(SystemExtensionStatus.installed);
      case 'requiresApproval':
        return const MacOSExtensionState(
          SystemExtensionStatus.requiresApproval,
        );
      case 'requiresReboot':
      case 'needsRestart':
        return MacOSExtensionState(
          SystemExtensionStatus.requiresReboot,
          details,
        );
      case 'updatePending':
        return MacOSExtensionState(
          SystemExtensionStatus.updatePending,
          details,
        );
      case 'timedOut':
        return const MacOSExtensionState(SystemExtensionStatus.timedOut);
      case 'activated':
        return const MacOSExtensionState(SystemExtensionStatus.activated);
      case 'deactivated':
        return const MacOSExtensionState(SystemExtensionStatus.deactivated);
      case 'uninstalling':
        return const MacOSExtensionState(SystemExtensionStatus.uninstalling);
      case 'error':
        return MacOSExtensionState(SystemExtensionStatus.error, details);
      default:
        return const MacOSExtensionState(SystemExtensionStatus.unknown);
    }
  }

  static String? _stringField(Map payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}
