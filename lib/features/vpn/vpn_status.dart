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
    final vpnStatus = ref.watch(vpnProvider);
    final statusValue = vpnStatus.name.capitalize;
    final textTheme = Theme.of(context).textTheme;
    MacOSExtensionState systemExtensionStatus =
        const MacOSExtensionState(SystemExtensionStatus.unknown);
    if (PlatformUtils.isMacOS) {
      systemExtensionStatus = ref.watch(macosExtensionProvider);
    }

    return SettingTile(
      key: Key('vpn.status.${vpnStatus.name}'),
      label: 'vpn_status'.i18n,
      value: statusValue,
      icon: AppImagePaths.glob,
      onTap: isExtensionNeeded(systemExtensionStatus)
          ? () {
              appRouter.push(const MacOSExtensionDialog());
            }
          : null,
      actions: [
        if (isExtensionNeeded(systemExtensionStatus))
          AppImage(path: AppImagePaths.warning, color: context.borderError)
        else
          VPNStatusIndicator(status: vpnStatus),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isExtensionNeeded(systemExtensionStatus))
            Text(
              'network_extension_required'.i18n,
              style:
                  textTheme.titleMedium!.copyWith(color: context.textPrimary),
            )
          else
            Text(statusValue,
                style: textTheme.titleMedium!
                    .copyWith(color: getStatusColor(vpnStatus, context))),
          if (vpnStatus == VPNStatus.connecting)
            AnimatedTextKit(
              animatedTexts: [
                TyperAnimatedText(
                  '... ',
                  textStyle: textTheme.titleMedium!
                      .copyWith(color: context.textPrimary),
                ),
                TyperAnimatedText('...',
                    textStyle: textTheme.titleMedium!
                        .copyWith(color: context.textPrimary)),
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
    if (systemExtensionStatus.status == SystemExtensionStatus.unknown) {
      return false;
    }
    return !systemExtensionStatus.isReady;
  }

  Color getStatusColor(VPNStatus vpnStatus, BuildContext context) {
    if (vpnStatus == VPNStatus.connected) {
      return context.statusSuccessText;
    }
    return context.textPrimary;
  }
}
