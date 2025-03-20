import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/preferences.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_notifier.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/split_tunneling/bottom_sheet.dart';

@RoutePage(name: 'SplitTunneling')
class SplitTunneling extends HookConsumerWidget {
  const SplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final splitTunnelingEnabled =
        preferences[AppPreferences.splitTunnelingEnabled] ?? false;
    final splitTunnelingMode = preferences[AppPreferences.splitTunnelingMode] ??
        SplitTunnelingMode.automatic;
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider).toList();

    return BaseScreen(
      title: 'split_tunneling'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          AppTile(
            icon: AppImagePaths.callSpilt,
            label: 'split_tunneling'.i18n,
            trailing: SizedBox(
              width: 44.0,
              child: CupertinoSwitch(
                value: splitTunnelingEnabled,
                activeTrackColor: CupertinoColors.activeGreen,
                onChanged: (bool? value) {
                  var newValue = value ?? false;
                  ref.read(appPreferencesProvider.notifier).setPreference(
                      AppPreferences.splitTunnelingEnabled, newValue);
                },
              ),
            ),
          ),
          const SizedBox(height: defaultSize),
          if (splitTunnelingEnabled)
            SplitTunnelingTile(
              label: 'mode'.i18n,
              // subtitle: Text(
              //   'iran_optimized'.i18n,
              //   style: AppTestStyles.labelSmall,
              // ),
              actionText: splitTunnelingMode == SplitTunnelingMode.automatic
                  ? 'automatic'.i18n
                  : 'manual'.i18n,
              onPressed: () => appRouter.push(AppsSplitTunneling()),
            ),
          SizedBox(height: defaultSize),
          InfoRow(
            onPressed: () => appRouter.push(SplitTunnelingInfo()),
            text: 'when_connected'.i18n,
          ),
          SizedBox(height: defaultSize),
          SplitTunnelingTile(
            label: 'Websites',
            actionText: '${enabledWebsites.length} Added',
            onPressed: () => appRouter.push(WebsiteSplitTunneling()),
          ),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }
}

class SplitTunnelingTile extends StatelessWidget {
  final String label;
  final String actionText;
  final VoidCallback onPressed;
  final Widget? subtitle;

  const SplitTunnelingTile({
    super.key,
    required this.label,
    required this.actionText,
    required this.onPressed,
    this.subtitle,
  });

  Widget build(BuildContext context) {
    return AppTile(
      label: label,
      subtitle: subtitle,
      onPressed: () => appRouter.push(WebsiteSplitTunneling()),
      trailing: Card(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppTextButton(
              //label: '${enabledWebsites.length} Added',
              label: actionText,
              onPressed: onPressed,
            ),
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: AppImage(path: AppImagePaths.arrowForward),
            ),
          ],
        ),
      ),
    );
  }
}
