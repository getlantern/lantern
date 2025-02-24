import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class VPNStatusIndicator extends StatelessWidget {
  final VPNStatus status;

  const VPNStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late String inidicator;
    switch (status) {
      case VPNStatus.connected:
        inidicator = AppImagePaths.vpnConnected;
        break;
      case VPNStatus.disconnected:
        inidicator = AppImagePaths.vpnDisconnected;
        break;
      case VPNStatus.connecting:
        inidicator = AppImagePaths.vpnConnecting;
        break;

      case VPNStatus.disconnecting:
        inidicator = AppImagePaths.vpnConnecting;
        break;
    }

    return AppAsset(path: inidicator);
  }
}
