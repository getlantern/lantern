import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/split_tunnel.dart';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/split_tunneling/apps_notifier.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';
import 'package:lantern/core/utils/ip_utils.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/utils/screen_utils.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/split_tunneling_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';

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
    final isAutomaticMode = splitTunnelingMode == SplitTunnelingMode.automatic;
    final enabledApps = ref.watch(splitTunnelingAppsProvider).toList();
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider).toList();
    final isExpanded = useState<bool>(false);

    void showBottomSheet() {
      showAppBottomSheet(
        context: context,
        title: 'split_tunneling_mode'.i18n,
        scrollControlDisabledMaxHeightRatio:
            context.isSmallDevice ? 0.39.h : 0.3.h,
        builder: (context, scrollController) {
          return Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                ...SplitTunnelingMode.values.map((mode) {
                  return SplitTunnelingModeTile(
                    mode: mode,
                    selectedMode: splitTunnelingMode,
                    onChanged: (newValue) {
                      if (newValue != null) {
                        ref.read(appPreferencesProvider.notifier).setPreference(
                            Preferences.splitTunnelingMode, newValue);
                        Navigator.pop(context);
                      }
                    },
                  );
                }),
              ],
            ),
          );
        },
      );
    }

    final locationSubtitle = useState<String>('global_optimized'.i18n);

    useEffect(() {
      IPUtils.getUserCountry().then((country) {
        switch (country) {
          case 'IR':
            locationSubtitle.value = 'iran_optimized'.i18n;
            break;
          case 'CN':
            locationSubtitle.value = 'china_optimized'.i18n;
            break;
          case 'RU':
            locationSubtitle.value = 'russia_optimized'.i18n;
            break;
          default:
            locationSubtitle.value = 'global_optimized'.i18n;
        }
      });
      return null;
    }, []);

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
                  trailing: SwitchButton(
                    value: splitTunnelingEnabled,
                    onChanged: (bool? value) {
                      var newValue = value ?? false;
                      ref.read(appPreferencesProvider.notifier).setPreference(
                          Preferences.splitTunnelingEnabled, newValue);
                    },
                  ),
                ),
                DividerSpace(),
                if (splitTunnelingEnabled) ...{
                  SplitTunnelingTile(
                    label: 'mode'.i18n,
                    subtitle: isAutomaticMode ? locationSubtitle.value : '',
                    actionText:
                        isAutomaticMode ? 'automatic'.i18n : 'manual'.i18n,
                    onPressed: () {
                      if (PlatformUtils.isDesktop) {
                        isExpanded.value = !isExpanded.value;
                      } else {
                        showBottomSheet();
                      }
                    },
                  ),
                  if (PlatformUtils.isDesktop && isExpanded.value)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 8.0),
                      child: Column(
                        children: SplitTunnelingMode.values.map((mode) {
                          return SplitTunnelingModeTile(
                            mode: mode,
                            selectedMode: splitTunnelingMode,
                            onChanged: (newValue) {
                              if (newValue != null) {
                                ref
                                    .read(appPreferencesProvider.notifier)
                                    .setPreference(
                                        Preferences.splitTunnelingMode,
                                        newValue);
                                isExpanded.value = false;
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                }
              ],
            ),
          ),
          SizedBox(height: defaultSize),
          InfoRow(
            onPressed: () {
              if (isAutomaticMode) {
                appRouter.push(
                  SplitTunnelingInfo(),
                );
              }
            },
            text: splitTunnelingEnabled
                ? (isAutomaticMode
                    ? 'lantern_automatic'.i18n
                    : 'when_connected'.i18n)
                : 'turn_on_split_tunneling'.i18n,
          ),
          if (splitTunnelingEnabled && !isAutomaticMode) ...{
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
    );
  }
}

class SplitTunnelingModeTile extends StatelessWidget {
  final SplitTunnelingMode mode;
  final SplitTunnelingMode selectedMode;
  final ValueChanged<SplitTunnelingMode?> onChanged;

  const SplitTunnelingModeTile({
    super.key,
    required this.mode,
    required this.selectedMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedMode == mode;

    return InkWell(
      onTap: () => onChanged(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gray2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                mode.displayName,
                style: AppTestStyles.bodyMedium.copyWith(
                  color: AppColors.black1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 24,
                color: isSelected ? AppColors.black1 : AppColors.gray12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
