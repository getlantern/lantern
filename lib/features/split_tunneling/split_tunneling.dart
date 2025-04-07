import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/split_tunneling/apps_notifier.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/split_tunneling/bottom_sheet.dart';

@RoutePage(name: 'SplitTunneling')
class SplitTunneling extends HookConsumerWidget {
  const SplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final splitTunnelingEnabled =
        preferences?[Preferences.splitTunnelingEnabled] ?? false;
    final splitTunnelingMode = preferences?[Preferences.splitTunnelingMode] ??
        SplitTunnelingMode.automatic;
    final enabledApps = ref.watch(splitTunnelingAppsProvider).toList();
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider).toList();

    void _showBottomSheet() {
      showAppBottomSheet(
        context: context,
        title: 'split_tunneling_mode'.i18n,
        scrollControlDisabledMaxHeightRatio:
            context.isSmallDevice ? 0.39.h : 0.3.h,
        builder: (context, scrollController) {
          return Expanded(
            child: SplitTunnelingBottomSheet(
              scrollController: scrollController,
              selectedMode: splitTunnelingMode,
              onModeSelected: (mode) => ref
                  .read(appPreferencesProvider.notifier)
                  .setPreference(Preferences.splitTunnelingMode, mode),
            ),
          );
        },
      );
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
                  icon: AppImagePaths.callSpilt,
                  label: 'split_tunneling'.i18n,
                  tileTextStyle: AppTestStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Switch.adaptive(
                      value: splitTunnelingEnabled,
                      activeTrackColor: AppColors.green5,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: AppColors.white,
                      inactiveTrackColor: AppColors.gray7,
                      inactiveThumbColor: AppColors.gray1,
                      onChanged: (bool? value) {
                        var newValue = value ?? false;
                        ref.read(appPreferencesProvider.notifier).setPreference(
                            Preferences.splitTunnelingEnabled, newValue);
                      },
                    ),
                  ),
                ),
                DividerSpace(),
                if (splitTunnelingEnabled)
                  SplitTunnelingTile(
                    label: 'mode'.i18n,
                    subtitle: 'iran_optimized'.i18n,
                    actionText:
                        splitTunnelingMode == SplitTunnelingMode.automatic
                            ? 'automatic'.i18n
                            : 'manual'.i18n,
                    onPressed: _showBottomSheet,
                  ),
                SizedBox(height: defaultSize),
                InfoRow(
                  onPressed: () {
                    if (splitTunnelingMode == SplitTunnelingMode.automatic) {
                      appRouter.push(
                        SplitTunnelingInfo(),
                      );
                    }
                  },
                  text: splitTunnelingEnabled
                      ? 'when_connected'.i18n
                      : 'turn_on_split_tunneling'.i18n,
                ),
                if (splitTunnelingEnabled) ...{
                  SizedBox(height: defaultSize),
                  SplitTunnelingTile(
                    label: 'Websites',
                    actionText: '${enabledWebsites.length} Added',
                    onPressed: () => appRouter.push(WebsiteSplitTunneling()),
                  ),
                  DividerSpace(),
                  SplitTunnelingTile(
                    label: 'Apps',
                    actionText: '${enabledApps.length} Added',
                    onPressed: () => appRouter.push(AppsSplitTunneling()),
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

class SplitTunnelingTile extends StatelessWidget {
  final String label;
  final String actionText;
  final VoidCallback onPressed;
  final String? subtitle;

  const SplitTunnelingTile({
    super.key,
    required this.label,
    required this.actionText,
    required this.onPressed,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: label,
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTestStyles.labelSmall.copyWith(
                color: AppColors.gray7,
              ),
            )
          : null,
      onPressed: () => appRouter.push(WebsiteSplitTunneling()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppTextButton(
            label: actionText,
            onPressed: onPressed,
          ),
          AppImage(
            path: AppImagePaths.arrowForward,
            height: 20,
          ),
        ],
      ),
    );
  }
}
