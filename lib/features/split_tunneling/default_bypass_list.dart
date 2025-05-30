import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

final selectedBypassListProvider =
    StateProvider<BypassListOption>((ref) => BypassListOption.global);

@RoutePage(name: 'DefaultBypassLists')
class DefaultBypassLists extends HookConsumerWidget {
  const DefaultBypassLists({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appSettingNotifierProvider);
    final notifier = ref.read(appSettingNotifierProvider.notifier);

    Future<void> onBypassTap(BypassListOption option) async {
      notifier.setByassList(option);
    }

    final bypassListOptions = [
      BypassListOption.global,
      BypassListOption.china,
      BypassListOption.iran,
      BypassListOption.russia,
    ];

    return BaseScreen(
      title: 'default_bypass'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...bypassListOptions.map(
              (bypassList) => AppTile(
                label: '${bypassList.value}_bypass_list'.i18n,
                subtitle: Text(
                  '${bypassList.value}_bypass_desc'.i18n,
                  style: AppTestStyles.labelMedium.copyWith(
                    color: AppColors.gray7,
                    height: 1.33,
                  ),
                ),
                trailing: Radio<BypassListOption>(
                  value: BypassListOption.global,
                  groupValue: preferences.bypassList,
                  onChanged: (value) => onBypassTap(bypassList),
                ),
                onPressed: () => onBypassTap(bypassList),
              ),
            ),
            AppTile.link(
              icon: AppImagePaths.info,
              label: 'see_sites_included'.i18n,
              url: 'https://getlantern.org/bypass-lists',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              subtitle: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'default_lists_here'.i18n,
                      style: AppTestStyles.titleSmall.copyWith(
                        color: AppColors.linkColor,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        height: 1.43,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
