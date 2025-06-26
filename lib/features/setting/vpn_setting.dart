import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

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
    final preferences = ref.watch(appSettingNotifierProvider);
    final splitTunnelingEnabled = preferences.isSplitTunnelingOn;
    return ListView(
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      children: <Widget>[
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (PlatformUtils.isAndroid) ...{
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
                onPressed: () {},
              ),
            ],
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
                onPressed: () => appRouter.push(const PrivateServerSetup()),
              ),
              DividerSpace(),
              AppTile(
                label: 'join_private_server'.i18n,
                icon: AppImagePaths.joinServer,
                onPressed: () => appRouter.push(const JoinPrivateServer()),
              ),
              DividerSpace(),
              AppTile(
                label: 'manage_private_servers'.i18n,
                icon: AppImagePaths.settingServer,
                onPressed: () => appRouter.push(const PrivateServerSetup()),
              ),
            ],
          ),
        ),

      ],
    );
  }
}
