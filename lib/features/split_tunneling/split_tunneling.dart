import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';

@RoutePage(name: 'SplitTunneling')
class SplitTunneling extends HookConsumerWidget {
  const SplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appSettingProvider);
    final textTheme = Theme.of(context).textTheme;
    final splitTunnelingEnabled = preferences.isSplitTunnelingOn;
    final enabledApps = ref.watch(splitTunnelingAppsProvider).toList();
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider).toList();
    final notifier = ref.read(appSettingProvider.notifier);

    void toggleSplitTunneling() {
      notifier.setSplitTunnelingEnabled(!splitTunnelingEnabled);
    }


    return BaseScreen(
      title: 'split_tunneling'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  label: 'split_tunneling'.i18n,
                  tileTextStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.gray9,
                  ),
                  subtitle: Text(
                    'add_apps_websites_bypass_vpn'.i18n,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium!.copyWith(
                      color: AppColors.gray7,
                      letterSpacing: 0.0,
                    ),
                  ),
                  onPressed: toggleSplitTunneling,
                  trailing: SwitchButton(
                    value: splitTunnelingEnabled,
                    onChanged: (bool? value) {
                      final v = value ?? false;
                      ref
                          .read(appSettingProvider.notifier)
                          .setSplitTunnelingEnabled(v);
                    },
                    activeColor: AppColors.green5,
                  ),
                ),
                if (splitTunnelingEnabled) ...{
                  DividerSpace(),
                  SplitTunnelingTile(
                    icon: AppImagePaths.keypad,
                    label: 'Apps',
                    actionText: '${enabledApps.length} Added',
                    onPressed: () => appRouter.push(AppsSplitTunneling()),
                  ),
                  DividerSpace(),
                  SplitTunnelingTile(
                    icon: AppImagePaths.world,
                    label: 'Websites',
                    actionText: '${enabledWebsites.length} Added',
                    onPressed: () => appRouter.push(WebsiteSplitTunneling()),
                  ),
                }
              ],
            ),
          ),
        ],
      ),
    );
  }
}
