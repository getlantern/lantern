import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';

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
    final preferences = ref.watch(appPreferencesProvider).value;
    final splitTunnelingEnabled =
        preferences?[Preferences.splitTunnelingEnabled] ?? false;
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(0),
        shrinkWrap: true,
        children: <Widget>[
          SplitTunnelingTile(
            label: 'split_tunneling'.i18n,
            icon: AppImagePaths.callSpilt,
            actionText:
                splitTunnelingEnabled ? 'enabled'.i18n : 'disabled'.i18n,
            onPressed: () => appRouter.push(const SplitTunneling()),
          ),
          DividerSpace(),
          AppTile(
            label: 'server_locations'.i18n,
            icon: AppImagePaths.location,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
