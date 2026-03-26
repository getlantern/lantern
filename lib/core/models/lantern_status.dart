// enum LanternStatus {
//   connected,
//   disconnected,
//   connecting,
//   disconnecting,
//   missingPermission,
//   error,
// }

import '../common/common.dart';

enum VPNStatusOrigin { userAction, settingsMutation, system, unknown }

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
    final origin = _originFromJson(json['origin']);
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

  static VPNStatusOrigin _originFromJson(dynamic rawOrigin) {
    if (rawOrigin is! String) {
      return VPNStatusOrigin.unknown;
    }

    switch (rawOrigin.toLowerCase()) {
      case 'user_action':
        return VPNStatusOrigin.userAction;
      case 'settings_mutation':
        return VPNStatusOrigin.settingsMutation;
      case 'system':
        return VPNStatusOrigin.system;
      default:
        return VPNStatusOrigin.unknown;
    }
  }
}
