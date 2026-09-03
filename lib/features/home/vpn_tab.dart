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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (isUserPro) const SizedBox(height: 0) else const ProBanner(),
            const VPNSwitch(),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!isUserPro) ...[
                  if (serverType == ServerLocationType.privateServer)
                    InfoRow(text: 'private_server_usage_message'.i18n)
                  else if (!PlatformUtils.isIOS && !isSmallScreen(context))
                    const DataUsage(),
                ],
                const SizedBox(height: 8),
                _SettingCard(),
                SizedBox(height: 10.h),
              ],
            ),
          ],
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
    final isUserPro = ref.watch(isUserProProvider);
    final serverType = ref
        .watch(serverLocationProvider)
        .serverType
        .toServerLocationType;

    // Small screens only (engineering#3046); regular screens show the
    // standalone DataUsage card in VpnTab instead. Same visibility rules:
    // free users, not iOS, not private servers.
    final smallScreen = isSmallScreen(context);
    final showDataUsage =
        smallScreen &&
        !isUserPro &&
        serverType != ServerLocationType.privateServer &&
        !PlatformUtils.isIOS;
    final showRoutingMode = !PlatformUtils.isIOS;
    final showSplitTunneling =
        PlatformUtils.isAndroid ||
        PlatformUtils.isMacOS ||
        PlatformUtils.isWindows;

    // Small screens drop the > chevrons; rows stay tappable via onTap.
    final chevronActions = smallScreen
        ? const <Widget>[]
        : const <Widget>[AppImage(path: AppImagePaths.arrowForward)];
    final routingTile = SettingTile(
      label: 'routing_mode'.i18n,
      icon: AppImagePaths.route,
      value: routingMode.label(),
      actions: chevronActions,
      onTap: () => appRouter.push(const SmartRouting()),
    );
    final splitTunnelingTile = SettingTile(
      // Tapped by the split-tunneling smoke harness.
      tileKey: const Key('home.split_tunneling_setting'),
      label: 'split_tunneling'.i18n,
      icon: AppImagePaths.callSpilt,
      value: isSplitTunnelingOn ? 'enabled'.i18n : 'disabled'.i18n,
      actions: chevronActions,
      onTap: () => appRouter.push(const SplitTunneling()),
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
            // Brings its own trailing divider, shown only when visible.
            if (showDataUsage) const DataUsage(insideCard: true),
            const VpnStatus(),
            const DividerSpace(),
            const LocationSetting(),
            if (showRoutingMode || showSplitTunneling) const DividerSpace(),
            // Small screens: Routing Mode | Split Tunneling share one row;
            // otherwise stacked full-width rows.
            if (showRoutingMode && showSplitTunneling && smallScreen)
              Row(
                children: [
                  Expanded(child: routingTile),
                  SizedBox(
                    height: 40,
                    child: VerticalDivider(
                      width: 1,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                  ),
                  Expanded(child: splitTunnelingTile),
                ],
              )
            else ...[
              if (showRoutingMode) routingTile,
              if (showRoutingMode && showSplitTunneling) const DividerSpace(),
              if (showSplitTunneling) splitTunnelingTile,
            ],
          ],
        ),
      ),
    );
  }
}
