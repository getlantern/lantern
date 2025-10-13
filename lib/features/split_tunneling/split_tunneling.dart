import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/ip_utils.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/info_row.dart';
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
    final preferences = ref.watch(appSettingNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final splitTunnelingEnabled = preferences.isSplitTunnelingOn;
    final splitTunnelingMode = preferences.splitTunnelingMode;
    final isAutomaticMode = splitTunnelingMode == SplitTunnelingMode.automatic;
    final enabledApps = ref.watch(splitTunnelingAppsProvider).toList();
    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider).toList();
    final expansionTileController = useExpansionTileController();
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
                  tileTextStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.gray9,
                  ),
                  minHeight: 56,
                  trailing: SwitchButton(
                    value: splitTunnelingEnabled,
                    onChanged: (bool? value) {
                      final v = value ?? false;
                      ref
                          .read(appSettingNotifierProvider.notifier)
                          .setSplitTunnelingEnabled(v);
                    },
                    activeColor: AppColors.green5,
                  ),
                ),
                DividerSpace(),
                if (splitTunnelingEnabled) ...{
                  Theme(
                    data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        hoverColor: AppColors.blue1),
                    child: ExpansionTile(
                        enableFeedback: true,
                        controller: expansionTileController,
                        backgroundColor: Colors.transparent,
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          'mode'.i18n,
                          style: textTheme.bodyLarge!
                              .copyWith(color: AppColors.gray9),
                        ),
                        initiallyExpanded: false,
                        trailing: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppTextButton(
                              underLine: false,
                              label: toBeginningOfSentenceCase(isAutomaticMode
                                  ? 'automatic'.i18n
                                  : 'manual'.i18n),
                              onPressed: () =>
                                  expansionTileController.isExpanded
                                      ? expansionTileController.collapse()
                                      : expansionTileController.expand(),
                            ),
                            AnimatedBuilder(
                              animation: expansionTileController,
                              builder: (context, child) {
                                return AnimatedRotation(
                                  turns: expansionTileController.isExpanded
                                      ? 0.25
                                      : 0.0,
                                  duration: const Duration(milliseconds: 180),
                                  child: child,
                                );
                              },
                              child: AppImage(
                                path: AppImagePaths.arrowForward,
                                height: 20,
                              ),
                            ),
                          ],
                        ),
                        subtitle: isAutomaticMode
                            ? Text(
                                locationSubtitle.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelMedium!.copyWith(
                                  color: AppColors.gray7,
                                  letterSpacing: 0.0,
                                ),
                              )
                            : null,
                        children: [
                          DividerSpace(padding: EdgeInsets.zero),
                          AppTile(
                            contentPadding: EdgeInsets.zero,
                            minHeight: 50,
                            label: toBeginningOfSentenceCase(
                                SplitTunnelingMode.automatic.value)!,
                            tileTextStyle: textTheme.bodyMedium!
                                .copyWith(color: AppColors.gray9),
                            trailing: AppRadioButton<SplitTunnelingMode>(
                              value: SplitTunnelingMode.automatic,
                              groupValue: splitTunnelingMode,
                              onChanged: (value) {
                                ref
                                    .read(appSettingNotifierProvider.notifier)
                                    .setSplitTunnelingMode(value!);
                                expansionTileController.collapse();
                              },
                            ),
                          ),
                          AppTile(
                            minHeight: 50,
                            contentPadding: EdgeInsets.zero,
                            label: toBeginningOfSentenceCase(
                                SplitTunnelingMode.manual.value)!,
                            tileTextStyle: textTheme.bodyMedium!
                                .copyWith(color: AppColors.gray9),
                            trailing: AppRadioButton<SplitTunnelingMode>(
                              value: SplitTunnelingMode.manual,
                              groupValue: splitTunnelingMode,
                              onChanged: (value) {
                                ref
                                    .read(appSettingNotifierProvider.notifier)
                                    .setSplitTunnelingMode(value!);
                                expansionTileController.collapse();
                              },
                            ),
                          ),
                        ]),
                  )
                },
              ],
            ),
          ),
          SizedBox(height: defaultSize),
          InfoRow(
            onPressed: splitTunnelingEnabled && isAutomaticMode
                ? () {
                    if (isAutomaticMode) {
                      appRouter.push(SplitTunnelingInfo());
                    }
                  }
                : null,
            text: splitTunnelingEnabled
                ? (isAutomaticMode
                    ? 'lantern_automatic'.i18n
                    : 'when_connected'.i18n)
                : 'turn_on_split_tunneling'.i18n,
            child: AppRichText(
              texts: splitTunnelingEnabled
                  ? (isAutomaticMode
                      ? 'lantern_automatic'.i18n
                      : 'when_connected'.i18n)
                  : 'turn_on_split_tunneling'.i18n,
              boldTexts: (splitTunnelingEnabled && isAutomaticMode)
                  ? 'learn_more'.i18n
                  : '',
              boldUnderline: true,
              boldColor: AppColors.blue7,
            ),
          ),
          if (splitTunnelingEnabled && !isAutomaticMode) ...{
            SizedBox(height: defaultSize),
            DividerSpace(),
            SizedBox(height: defaultSize),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
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
                ],
              ),
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
                mode.value,
                style: AppTextStyles.bodyMedium.copyWith(
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
