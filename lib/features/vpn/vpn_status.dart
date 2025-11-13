import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/vpn_status_indicator.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../core/common/common.dart';
import '../macos_extension/provider/macos_extension_notifier.dart';

class VpnStatus extends HookConsumerWidget {
  const VpnStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnStatus = ref.watch(vpnNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    MacOSExtensionState systemExtensionStatus =
        MacOSExtensionState(SystemExtensionStatus.notInstalled);
    if (PlatformUtils.isMacOS) {
      systemExtensionStatus = ref.watch(macosExtensionNotifierProvider);
    }

    return SettingTile(
      label: 'vpn_status'.i18n,
      value: vpnStatus.name.capitalize,
      icon: AppImagePaths.glob,
      onTap: isExtensionNeeded(systemExtensionStatus)
          ? () {
              appRouter.push(const MacOSExtensionDialog());
            }
          : null,
      actions: [
        if (isExtensionNeeded(systemExtensionStatus))
          AppImage(path: AppImagePaths.warning, color: AppColors.red6)
        else
          VPNStatusIndicator(status: vpnStatus),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isExtensionNeeded(systemExtensionStatus))
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
                TyperAnimatedText(
                  '.  ',
                  textStyle:
                      textTheme.titleMedium!.copyWith(color: AppColors.gray9),
                ),
                TyperAnimatedText('.. ',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: AppColors.gray9)),
                TyperAnimatedText('...',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: AppColors.gray9)),
              ],
              repeatForever: true,
            )
        ],
      ),
    );
  }

  bool isExtensionNeeded(MacOSExtensionState systemExtensionStatus) {
    if (!PlatformUtils.isMacOS) {
      return false;
    }
    return (PlatformUtils.isMacOS &&
        systemExtensionStatus.status != SystemExtensionStatus.installed &&
        systemExtensionStatus.status != SystemExtensionStatus.activated);
  }

  Color getStatusColor(VPNStatus vpnStatus) {
    if (vpnStatus == VPNStatus.connected) {
      return AppColors.green6;
    }
    return AppColors.gray9;
  }
}
