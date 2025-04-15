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
    if (json['status'] == 'Connected') {
      status = VPNStatus.connected;
    } else if (json['status'] == 'Disconnected') {
      status = VPNStatus.disconnected;
    } else if (json['status'] == 'Connecting') {
      status = VPNStatus.connecting;
    } else if (json['status'] == 'Disconnecting') {
      status = VPNStatus.disconnecting;
    } else if (json['status'] == 'MissingPermission') {
      status = VPNStatus.disconnected;
    } else if (json['status'] == 'Error') {
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
