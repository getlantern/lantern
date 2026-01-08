import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/vpn_status.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

import '../../core/common/common.dart';

enum _SettingTileType {
  smartLocation,
  splitTunneling,
  smartRouting,
}

@RoutePage(name: 'Home')
class Home extends StatefulHookConsumerWidget {
  const Home({super.key});

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> with WidgetsBindingObserver {
  TextTheme? textTheme;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appSetting = ref.read(appSettingProvider);
      if (PlatformUtils.isMacOS) {
        /// Show macOS system extension dialog if needed
        appLogger.info(
            "App Setting - showSplashScreen: ${appSetting.showSplashScreen}");
        if (appSetting.showSplashScreen) {
          appLogger.info("Showing System Extension Dialog");
          appRouter.push(const MacOSExtensionDialog());
          //User has seen dialog, do not show again
          appLogger.info("Setting showSplashScreen to false");
          ref.read(appSettingProvider.notifier).setSplashScreen(false);
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUserPro = ref.watch(isUserProProvider);
    final featureFlag = ref.watch(featureFlagProvider);
    final appSetting = ref.read(appSettingProvider);
    useEffect(() {
      if (appSetting.successfulConnection) {
        appLogger.info(
            "User has successfully connected, checking if needs to show Help Lantern Dialog or not");
        if (!appSetting.telemetryDialogDismissed &&
            (featureFlag.getBool(FeatureFlag.metrics) &&
                featureFlag.getBool(FeatureFlag.traces))) {
          appLogger.info("Showing Help Lantern Dialog");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showHelpLanternDialog();
            ref.read(appSettingProvider.notifier).setShowTelemetryDialog(true);
          });
        }
      }
      return null;
    }, [featureFlag]);

    textTheme = Theme.of(context).textTheme;
    ref.read(appEventProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.white,
          title: LanternLogo(isPro: isUserPro),
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
      body: SafeArea(
        child: _buildBody(ref, isUserPro),
      ),
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
              SizedBox(height: 10.h),
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
                    icon: AppImage(path: AppImagePaths.arrowForward),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  )
                ],
                onTap: () => onSettingTileTap(_SettingTileType.splitTunneling),
              ),
              DividerSpace(),
              SettingTile(
                label: 'routing_mode'.i18n,
                icon: AppImagePaths.route,
                value: setting.isSplitTunnelingOn
                    ? setting.splitTunnelingMode.value.capitalize
                    : 'disabled'.i18n,
                actions: [
                  IconButton(
                    onPressed: () => appRouter.push(SplitTunneling()),
                    style: ElevatedButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: AppImage(path: AppImagePaths.arrowForward),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  )
                ],
                onTap: () => onSettingTileTap(_SettingTileType.smartRouting),
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
      case _SettingTileType.smartRouting:
        appRouter.push(const SmartRouting());
    }
  }

  void showHelpLanternDialog() {
    AppDialog.customDialog(
        context: context,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: 24),
            AppImage(path: AppImagePaths.assessment),
            SizedBox(height: 24),
            Text(
              'help_improve_lantern'.i18n,
              style: textTheme!.headlineSmall!.copyWith(
                color: AppColors.gray9,
              ),
            ),
            SizedBox(height: defaultSize),
            Text(
              'share_anonymous_usage_data'.i18n,
              style: textTheme!.bodyMedium!.copyWith(
                color: AppColors.gray8,
              ),
            ),
            SizedBox(height: defaultSize),
            Text(
              'data_we_collect'.i18n,
              style: AppTextStyles.bodyMediumBold.copyWith(
                color: AppColors.gray8,
              ),
            ),
            SizedBox(height: defaultSize),
            Text(
              'you_can_change_anytime'.i18n,
              style: textTheme!.bodyMedium!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ],
        ),
        action: [
          AppTextButton(
            label: 'dont_allow'.i18n,
            textColor: AppColors.gray6,
            onPressed: () {
              context.pop();
              ref
                  .read(appSettingProvider.notifier)
                  .updateAnonymousDataConsent(false);
            },
          ),
          AppTextButton(
            label: 'allow'.i18n,
            textColor: AppColors.blue6,
            onPressed: () {
              context.pop();
              ref
                  .read(appSettingProvider.notifier)
                  .updateAnonymousDataConsent(true);
            },
          ),
        ]);
  }
}
