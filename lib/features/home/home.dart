import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/vpn_status.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

import '../../core/common/common.dart';

enum _SettingTileType {
  smartLocation,
  splitTunneling,
}

@RoutePage(name: 'Home')
class Home extends HookConsumerWidget {
  Home({super.key});

  TextTheme? textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUserPro = ref.isUserPro;
    textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.white,
          title: LanternLogo(
            isPro: isUserPro,
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(0),
            child: DividerSpace(padding: EdgeInsets.zero),
          ),
          elevation: 5,
          leading: IconButton(
              onPressed: () {
                appRouter.push(Setting());
              },
              icon: const AppImage(path: AppImagePaths.menu))),
      body: _buildBody(ref, isUserPro),
    );
  }

  Widget _buildBody(WidgetRef ref, bool isUserPro) {
    final serverLocation = ref.watch(serverLocationNotifierProvider);
    final serverType = serverLocation.serverType.toServerLocationType;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: defaultSize),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (isUserPro) SizedBox(height: 0) else ProBanner(),
          VPNSwitch(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!isUserPro) ...{
                if (serverType == ServerLocationType.privateServer)
                  InfoRow(
                    text: 'private_server_usage_message'.i18n,
                    onPressed: () {},
                  )
                else
                  DataUsage(),
              },
              SizedBox(height: 8),
              _buildSetting(ref),
              SizedBox(height: 20.h),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetting(WidgetRef ref) {
    final preferences = ref.watch(appSettingNotifierProvider);
    final splitTunnelingEnabled = preferences.isSplitTunnelingOn;
    final serverLocation = ref.watch(serverLocationNotifierProvider);
    final serverType = serverLocation.serverType.toServerLocationType;
    switch (serverType) {
      case ServerLocationType.auto:
      case ServerLocationType.lanternLocation:
      case ServerLocationType.privateServer:
    }

    return Container(
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 32,
          offset: Offset(0, 4),
          spreadRadius: 0,
        )
      ]),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            VpnStatus(),
            DividerSpace(),
            SettingTile(
              label: getServerTitle(serverLocation),
              value: getServerValue(serverLocation),
              icon: serverType == ServerLocationType.auto
                  ? AppImagePaths.location
                  : Flag(
                      countryCode: serverLocation.serverLocation.countryCode),
              actions: [
                if (serverType == ServerLocationType.auto)
                  AppImage(path: AppImagePaths.blot),
                SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    appRouter.push(const ServerSelection());
                  },
                  style: ElevatedButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: AppImage(path: AppImagePaths.verticalDots),
                  padding: EdgeInsets.zero,
                  // iconSize: 10,
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                )
              ],
              onTap: () => onSettingTileTap(_SettingTileType.smartLocation),
            ),
            if (PlatformUtils.isAndroid || PlatformUtils.isMacOS) ...{
              DividerSpace(),
              SettingTile(
                label: 'split_tunneling'.i18n,
                icon: AppImagePaths.callSpilt,
                value: splitTunnelingEnabled ? 'Enabled' : 'Disabled',
                actions: [
                  IconButton(
                    onPressed: () => appRouter.push(SplitTunneling()),
                    style: ElevatedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: AppImage(path: AppImagePaths.verticalDots),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  )
                ],
                onTap: () => onSettingTileTap(_SettingTileType.splitTunneling),
              ),
            },
          ],
        ),
      ),
    );
  }

  void onSettingTileTap(_SettingTileType tileType) {
    switch (tileType) {
      case _SettingTileType.smartLocation:
        appRouter.push(const ServerSelection());
        break;
      case _SettingTileType.splitTunneling:
        appRouter.push(const SplitTunneling());
        break;
    }
  }

  String getServerTitle(ServerLocationEntity serverLocation) {
    switch (serverLocation.serverType.toServerLocationType) {
      case ServerLocationType.auto:
        return 'Smart Location';
      case ServerLocationType.lanternLocation:
        return 'Selected Location';
      case ServerLocationType.privateServer:
        return serverLocation.serverName;
    }
  }

  String getServerValue(ServerLocationEntity serverLocation) {
    switch (serverLocation.serverType.toServerLocationType) {
      case ServerLocationType.auto:
        return 'Fastest Country';
      case ServerLocationType.lanternLocation:
        return serverLocation.serverLocation;
      case ServerLocationType.privateServer:
        return serverLocation.serverLocation.locationName;
    }
  }
}
