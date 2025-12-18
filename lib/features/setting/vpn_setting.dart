import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

import '../home/provider/local_storage_notifier.dart';

@RoutePage(name: 'VPNSetting')
class VPNSetting extends HookConsumerWidget {
  const VPNSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      title: 'vpn_settings'.i18n,
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isUserPro = ref.watch(isUserProProvider);
    final isPrivateServerFound =
        ref.read(localStorageProvider).getPrivateServer().isNotEmpty;
    final preferences = ref.read(appSettingProvider);
    final notifier = ref.watch(appSettingProvider.notifier);
    final splitTunnelingEnabled =
        ref.read(appSettingProvider).isSplitTunnelingOn;
    return ListView(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      children: <Widget>[
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (PlatformUtils.isAndroid || PlatformUtils.isMacOS) ...{
                SplitTunnelingTile(
                  label: 'split_tunneling'.i18n,
                  icon: AppImagePaths.callSpilt,
                  actionText:
                      splitTunnelingEnabled ? 'enabled'.i18n : 'disabled'.i18n,
                  onPressed: () => appRouter.push(const SplitTunneling()),
                ),
                DividerSpace()
              },
              AppTile(
                label: 'server_locations'.i18n,
                icon: AppImagePaths.location,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () {
                  appRouter.push(const ServerSelection());
                },
              ),
              DividerSpace(),
              AppTile(
                label: 'anonymous_usage_data'.i18n,
                icon: AppImagePaths.assessment,
                subtitle: Text(
                  'helps_improve_lantern_performance'.i18n,
                  style: textTheme.labelMedium!.copyWith(
                    color: AppColors.gray7,
                    letterSpacing: 0.0,
                  ),
                ),
                trailing: SwitchButton(
                  value: preferences.telemetryConsent,
                  onChanged: (value) {
                    appLogger
                        .info('Anonymous usage data consent changed: $value');
                    notifier.updateAnonymousDataConsent(value);
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            label: 'block_ads'.i18n,
            subtitle: Text(
              'only_active'.i18n,
              style: textTheme.labelMedium!.copyWith(
                color: AppColors.gray7,
                letterSpacing: 0.0,
              ),
            ),
            icon: AppImagePaths.blockAds,
            trailing: SwitchButton(
              value: preferences.blockAds,
              onChanged: (bool? value) {
                if (!isUserPro) {
                  appRouter.push(Plans());
                  return;
                }
                var newValue = value ?? false;
                notifier.setBlockAds(newValue);
              },
            ),
            onPressed: () {
              if (!isUserPro) {
                appRouter.push(Plans());
                return;
              }
              var newValue = !preferences.blockAds;
              notifier.setBlockAds(newValue);
            },
          ),
        ),
        SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTile(
                label: 'setup_private_server'.i18n,
                icon: AppImagePaths.server,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () => appRouter.push(const PrivateServerSetup()),
              ),
              DividerSpace(),
              AppTile(
                label: 'join_private_server'.i18n,
                icon: AppImagePaths.joinServer,
                trailing: AppImage(
                  path: AppImagePaths.arrowForward,
                  height: 20,
                ),
                onPressed: () => appRouter.push(JoinPrivateServer()),
              ),
              DividerSpace(),
              if (isPrivateServerFound)
                AppTile(
                  label: 'manage_private_servers'.i18n,
                  icon: AppImagePaths.settingServer,
                  trailing: AppImage(
                    path: AppImagePaths.arrowForward,
                    height: 20,
                  ),
                  onPressed: () => appRouter.push(const ManagePrivateServer()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
