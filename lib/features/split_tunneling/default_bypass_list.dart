import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_field.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/radio_listview.dart';
import 'package:lantern/features/split_tunneling/provider/app_preferences.dart';

final selectedBypassListProvider =
    StateProvider<BypassListOption>((ref) => BypassListOption.global);

@RoutePage(name: 'DefaultBypassLists')
class DefaultBypassLists extends HookConsumerWidget {
  const DefaultBypassLists({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final selectedList = preferences.value?[Preferences.defaultBypassList] ??
        BypassListOption.global;

    Future<void> onBypassTap(BypassListOption option) async {
      notifier.setBypassList(option);
    }

    return BaseScreen(
      title: 'default_bypass'.i18n,
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            AppTile(
              label: 'global_bypass_list'.i18n,
              subtitle: Text(
                'global_bypass_desc'.i18n,
                style: AppTestStyles.labelMedium.copyWith(
                  color: AppColors.gray7,
                  height: 1.33,
                ),
              ),
              trailing: Radio<BypassListOption>(
                value: BypassListOption.global,
                groupValue: selectedList,
                onChanged: (value) => onBypassTap(BypassListOption.global),
              ),
              onPressed: () => onBypassTap(BypassListOption.global),
            ),
            AppTile(
              label: 'china_bypass_list'.i18n,
              subtitle: Text(
                'china_bypass_desc',
                style: AppTestStyles.labelMedium.copyWith(
                  color: AppColors.gray7,
                  height: 1.33,
                ),
              ),
              trailing: Radio<BypassListOption>(
                value: BypassListOption.china,
                groupValue: selectedList,
                onChanged: (value) => onBypassTap(BypassListOption.china),
              ),
              onPressed: () => onBypassTap(BypassListOption.china),
            ),
            AppTile(
              label: 'iran_bypass_list'.i18n,
              subtitle: Text(
                'iran_bypass_desc'.i18n,
                style: AppTestStyles.labelMedium.copyWith(
                  color: AppColors.gray7,
                  height: 1.33,
                ),
              ),
              trailing: Radio<BypassListOption>(
                value: BypassListOption.iran,
                groupValue: selectedList,
                onChanged: (value) => onBypassTap(BypassListOption.iran),
              ),
              onPressed: () => onBypassTap(BypassListOption.iran),
            ),
            AppTile(
              label: 'russia_bypass_list'.i18n,
              subtitle: Text(
                'russia_bypass_desc',
                style: AppTestStyles.labelMedium.copyWith(
                  color: AppColors.gray7,
                  height: 1.33,
                ),
              ),
              trailing: Radio<BypassListOption>(
                value: BypassListOption.russia,
                groupValue: selectedList,
                onChanged: (value) => onBypassTap(BypassListOption.russia),
              ),
              onPressed: () => onBypassTap(BypassListOption.russia),
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
                      text: 'see_sites_included'.i18n,
                      style: AppTestStyles.titleSmall.copyWith(
                        color: AppColors.logTextColor,
                        fontWeight: FontWeight.w500,
                        height: 1.43,
                      ),
                    ),
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

  // Future<void> openBypassSelection(BuildContext context) async {
  //   showAppBottomSheet(
  //     context: context,
  //     title: 'default_bypass_lists'.i18n,
  //     builder: (context, scrollController) {
  //       return Expanded(
  //           child: RadioListView(
  //         scrollController: scrollController,
  //         items: bypassOptions,
  //         onTap: _onBypassTap,
  //       ));
  //     },
  //   );
  // }
}
