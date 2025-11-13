// enum LanternStatus {
//   connected,
//   disconnected,
//   connecting,
//   disconnecting,
//   missingPermission,
//   error,
// }

import '../common/common.dart';

class LanternStatus {
  final VPNStatus status;
  final Error? error;

  factory LanternStatus.fromJson(Map<String, dynamic> json) {
    appLogger.info('LanternStatus.fromJson $json');
    VPNStatus status = VPNStatus.disconnected;
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
    }
    return LanternStatus(
      status: status,
    );
  }

  LanternStatus({required this.status, this.error});

  @override
  String toString() => 'LanternStatus(status: $status, error: $error)';
}
