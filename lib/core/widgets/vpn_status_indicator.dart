import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class VPNStatusIndicator extends StatelessWidget {
  final VPNStatus status;

  const VPNStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case VPNStatus.connected:
        return const StatusDot(active: true);
      case VPNStatus.disconnected:
        return const StatusDot(active: false);
      case VPNStatus.connecting:
      case VPNStatus.missingPermission:
      case VPNStatus.error:
      case VPNStatus.disconnecting:
        return const AppImage(
          path: AppImagePaths.vpnConnecting,
          useThemeColor: false,
        );
    }
  }
}

/// Green/grey status light shared by every "is this feature running" surface
/// in the app (VPN status row, VPN/Unbounded tab strip) so they all read the
/// same on/off signal the same way. Reuses the exact assets and grey-tint
/// trick VPNStatusIndicator uses for its connected/disconnected states.
class StatusDot extends StatelessWidget {
  final bool active;

  const StatusDot({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return AppImage(
      path: active ? AppImagePaths.vpnConnected : AppImagePaths.vpnDisconnected,
      useThemeColor: false,
      color: active ? null : AppColors.gray3,
    );
  }
}
