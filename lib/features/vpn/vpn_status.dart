import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/home/provider/system_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../core/common/common.dart';

class VpnStatus extends HookConsumerWidget {
  const VpnStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnStatus = ref.watch(vpnNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    SystemExtensionStatus systemExtensionStatus = SystemExtensionStatus.unknown;
    if (PlatformUtils.isMacOS) {
      systemExtensionStatus = ref.watch(systemExtensionNotifierProvider);
    }

    return SettingTile(
      label: 'vpn_status'.i18n,
      value: vpnStatus.name.capitalize,
      icon: AppImagePaths.glob,
      onTap: systemExtensionStatus ==
              SystemExtensionStatus.notInstalled
          ? () {
              appRouter.push(const SystemExtensionDialog());
            }
          : null,
      actions: [
        if (systemExtensionStatus != SystemExtensionStatus.installed)
          AppImage(path: AppImagePaths.warning, color: AppColors.red6)
        else
          VPNStatusIndicator(status: vpnStatus),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (systemExtensionStatus == SystemExtensionStatus.notInstalled)
            Text(
              'network_extension_required'.i18n,
              style: textTheme.titleMedium!.copyWith(color: AppColors.gray9),
            )
          else
            Text(vpnStatus.name.capitalize,
                style: textTheme.titleMedium!
                    .copyWith(color: getStatusColor(vpnStatus))),
          if (vpnStatus == VPNStatus.connecting)
            AnimatedTextKit(
              animatedTexts: [
                TyperAnimatedText('.  ',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: AppColors.gray9, fontSize: 20)),
                TyperAnimatedText('.. ',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: AppColors.gray9, fontSize: 20)),
                TyperAnimatedText('...',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: AppColors.gray9, fontSize: 20)),
              ],
              repeatForever: true,
            )
        ],
      ),
    );
  }

  Color getStatusColor(VPNStatus vpnStatus) {
    if (vpnStatus == VPNStatus.connected) {
      AppColors.green6;
    }
    return AppColors.gray9;
  }
}
