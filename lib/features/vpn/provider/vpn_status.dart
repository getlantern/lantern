import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../../core/common/common.dart';

class VpnStatus extends HookConsumerWidget {
  const VpnStatus({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _vpnStatus = ref.watch(vpnNotifierProvider);
    return SettingTile(
      label: 'vpn_status'.i18n,
      value: _vpnStatus.name.capitalize,
      icon: AppImagePaths.glob,
      actions: [
        VPNStatusIndicator(status: _vpnStatus),
      ],
    );
  }
}
