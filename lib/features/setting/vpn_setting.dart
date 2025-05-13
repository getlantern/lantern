import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';

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
    final homeState = ref.watch(homeNotifierProvider);
    final isUserPro =
        homeState.valueOrNull?.legacyUserData.userStatus == 'pro' ?? false;
    final preferences = ref.watch(appPreferencesProvider).value;
    final splitTunnelingEnabled =
        preferences?[Preferences.splitTunnelingEnabled] ?? false;
    final blockAds = preferences?[Preferences.blockAds] ?? false;

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
          AppTile(
            label: 'block_ads'.i18n,
            subtitle: Text(
              'only_active'.i18n,
              style: textTheme.labelMedium!.copyWith(
                color: AppColors.gray7,
              ),
            ),
            icon: AppImagePaths.blockAds,
            trailing: SwitchButton(
              value: blockAds,
              onChanged: (bool? value) {
                if (!isUserPro) {
                  appRouter.pushNamed('/plans-bottom');
                  return;
                }
                var newValue = value ?? false;
                ref
                    .read(appPreferencesProvider.notifier)
                    .setPreference(Preferences.blockAds, newValue);
              },
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
