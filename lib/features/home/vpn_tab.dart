import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/vpn_status.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

import '../../core/common/common.dart';

/// VPN tab body — the connect toggle, data usage, location, routing and
/// split-tunnel rows. Originally the body of the Home screen; lifted out
/// when Home was refactored into a two-tab shell (VPN + Unbounded). No
/// Scaffold or AppBar — the shell provides that chrome.
class VpnTab extends ConsumerWidget {
  const VpnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUserPro = ref.watch(isUserProProvider);
    final serverLocation = ref.watch(serverLocationProvider);
    final serverType = serverLocation.serverType.toServerLocationType;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: defaultSize),
        // Preserve the spaced layout when it fits while allowing the body to
        // grow and scroll when the window leaves less vertical room.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  if (isUserPro) const SizedBox.shrink() else const ProBanner(),
                  const VPNSwitch(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (!isUserPro) ...{
                        if (serverType == ServerLocationType.privateServer)
                          InfoRow(text: 'private_server_usage_message'.i18n)
                        else if (PlatformUtils.isIOS)
                          const SizedBox.shrink()
                        else
                          const DataUsage(),
                      },
                      const SizedBox(height: 8),
                      _SettingCard(),
                      SizedBox(height: 10.h),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routingMode = ref.watch(
      radianceSettingsProvider.select((s) => s.routingMode),
    );
    final isSplitTunnelingOn = ref.watch(
      radianceSettingsProvider.select((s) => s.splitTunneling),
    );

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 32,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            const VpnStatus(),
            const DividerSpace(),
            const LocationSetting(),
            if (!PlatformUtils.isIOS) ...{
              const DividerSpace(),
              SettingTile(
                label: 'routing_mode'.i18n,
                icon: AppImagePaths.route,
                value: routingMode.label(),
                actions: [
                  IconButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const AppImage(path: AppImagePaths.arrowForward),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                onTap: () => appRouter.push(const SmartRouting()),
              ),
            },
            if (PlatformUtils.isAndroid ||
                PlatformUtils.isMacOS ||
                PlatformUtils.isWindows) ...{
              const DividerSpace(),
              SettingTile(
                label: 'split_tunneling'.i18n,
                icon: AppImagePaths.callSpilt,
                value: isSplitTunnelingOn ? 'enabled'.i18n : 'disabled'.i18n,
                actions: [
                  IconButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const AppImage(path: AppImagePaths.arrowForward),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                onTap: () => appRouter.push(const SplitTunneling()),
              ),
            },
          ],
        ),
      ),
    );
  }
}
