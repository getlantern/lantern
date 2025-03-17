import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

class VPNStatusIndicator extends HookConsumerWidget {
  final VPNStatus status;

  const VPNStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    late String indicator;
    switch (status) {
      case VPNStatus.connected:
        indicator = AppImagePaths.vpnConnected;
        break;
      case VPNStatus.disconnected:
        indicator = AppImagePaths.vpnDisconnected;
        break;
      case VPNStatus.connecting:
        indicator = AppImagePaths.vpnConnecting;
        break;
      case VPNStatus.disconnecting:
        indicator = AppImagePaths.vpnConnecting;
        break;
    }

    return AppImage(path: indicator);
  }
}
