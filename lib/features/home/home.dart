import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/vpn_status.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';
import 'package:lantern/lantern_app.dart';

import '../../core/common/common.dart';

enum _SettingTileType {
  smartLocation,
  splitTunneling,
}

@RoutePage(name: 'Home')
class Home extends StatefulHookConsumerWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home>
    with RouteAware, WidgetsBindingObserver {
  TextTheme? textTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (PlatformUtils.isMacOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appSetting = ref.read(appSettingProvider);
        appLogger.info(
            "App Setting - showSplashScreen: ${appSetting.showSplashScreen}");
        if (appSetting.showSplashScreen) {
          appLogger.info("Showing System Extension Dialog");
          appRouter.push(const MacOSExtensionDialog());
          //User has seen dialog, do not show again
          appLogger.info("Setting showSplashScreen to false");
          ref.read(appSettingProvider.notifier).setSplashScreen(false);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      appLogger.debug("App resumed - checking auto server location");

      /// User comes back to home screen
      ref.read(serverLocationProvider.notifier).ifNeededGetAutoServerLocation();
    }
  }

  @override
  void didPopNext() {
    /// User comes back to home screen
    ref.read(serverLocationProvider.notifier).ifNeededGetAutoServerLocation();
    super.didPopNext();
  }

  @override
  void didPush() {
    /// First time screen is pushed
    ref.read(serverLocationProvider.notifier).ifNeededGetAutoServerLocation();
    super.didPush();
  }

  @override
  Widget build(BuildContext context) {
    final isUserPro = ref.watch(isUserProProvider);
    textTheme = Theme.of(context).textTheme;
    ref.read(appEventProvider);
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
    final serverLocation = ref.watch(serverLocationProvider);
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
                  )
                else
                  const SizedBox()
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
    final setting = ref.watch(appSettingProvider);

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
            LocationSetting(),
            if (PlatformUtils.isAndroid ||
                PlatformUtils.isMacOS ||
                PlatformUtils.isWindows) ...{
              DividerSpace(),
              SettingTile(
                label: 'split_tunneling'.i18n,
                icon: AppImagePaths.callSpilt,
                value: setting.isSplitTunnelingOn
                    ? setting.splitTunnelingMode.value.capitalize
                    : 'disabled'.i18n,
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
}
