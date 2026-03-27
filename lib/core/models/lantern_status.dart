// enum LanternStatus {
//   connected,
//   disconnected,
//   connecting,
//   disconnecting,
//   missingPermission,
//   error,
// }

import '../common/common.dart';

enum VPNStatusOrigin {
  userAction('user_action'),
  settingsMutation('settings_mutation'),
  system('system'),
  unknown('unknown');

  const VPNStatusOrigin(this.wireValue);

  final String wireValue;

  static VPNStatusOrigin fromWire(dynamic rawOrigin) {
    if (rawOrigin is! String) {
      return VPNStatusOrigin.unknown;
    }

    final normalized = rawOrigin.toLowerCase();
    for (final origin in VPNStatusOrigin.values) {
      if (origin.wireValue == normalized) {
        return origin;
      }
    }
    return VPNStatusOrigin.unknown;
  }
}

class LanternStatus {
  final VPNStatus status;
  final String? error;
  final VPNStatusOrigin origin;

  factory LanternStatus.fromJson(Map<String, dynamic> json) {
    appLogger.info('LanternStatus.fromJson $json');
    final VPNStatus status;
    final String statusStr = json['status'].toLowerCase();
    if (statusStr == 'connected') {
      status = VPNStatus.connected;
    } else if (statusStr == 'disconnected') {
      status = VPNStatus.disconnected;
    } else if (statusStr == 'connecting') {
      status = VPNStatus.connecting;
    } else if (statusStr == 'disconnecting') {
      status = VPNStatus.disconnecting;
    } else if (statusStr == 'missingpermission') {
      status = VPNStatus.disconnected;
    } else if (statusStr == 'error') {
      status = VPNStatus.error;
    } else {
      appLogger.error('Unknown status: $statusStr');
      status = VPNStatus.disconnected;
    }
    final origin = VPNStatusOrigin.fromWire(json['origin']);
    return LanternStatus(status: status, error: json['error'], origin: origin);
  }

  LanternStatus({
    required this.status,
    this.error,
    this.origin = VPNStatusOrigin.unknown,
  });

  @override
  String toString() =>
      'LanternStatus(status: $status, error: $error, origin: $origin)';
}
