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
  final String? error;

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
    return LanternStatus(
      status: status,
      error: json['error'],
    );
  }

  LanternStatus({required this.status, this.error});

  @override
  String toString() => 'LanternStatus(status: $status, error: $error)';
}
