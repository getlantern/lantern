import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';

@RoutePage(name: 'DefaultBypassLists')
class DefaultBypassLists extends HookConsumerWidget {
  const DefaultBypassLists({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appSettingNotifierProvider);
    final selectedBypassList = preferences.bypassList;
    final websiteNr = ref.read(splitTunnelingWebsitesProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    Future<void> onBypassTap(BypassListOption option) async {
      final currentList = selectedBypassList;
      final updatedList = currentList.contains(option)
          ? (currentList..remove(option)) // remove if already selected
          : (currentList..add(option)); // add if not selected

      websiteNr.updateByPassList(updatedList);
      Future.delayed(const Duration(milliseconds: 500), () {
        appRouter.pop();
      });
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
            AppCard(
                padding: EdgeInsets.zero,
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: bypassListOptions
                      .map(
                        (bypassList) => Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            AppTile(
                              label: '${bypassList.value}_bypass_list'.i18n,
                              subtitle: Text(
                                '${bypassList.value}_bypass_desc'.i18n,
                                style: textTheme.labelMedium!
                                    .copyWith(color: AppColors.gray7),
                              ),
                              trailing:
                                  preferences.bypassList.contains(bypassList)
                                      ? Icon(Icons.check_circle)
                                      : Icon(Icons.radio_button_off),
                              onPressed: () => onBypassTap(bypassList),
                            ),
                            DividerSpace(padding: EdgeInsets.zero),
                          ],
                        ),
                      )
                      .toList(),
                )),
            SizedBox(height: defaultSize),
            InfoRow(
              minTileHeight: 35,
              text: '',
              child: AppRichText(
                texts: 'see_sites_included'.i18n,
                boldTexts: 'default_lists_here'.i18n,
                boldColor: AppColors.blue7,
                boldUnderline: true,
                boldOnPressed: () {
                  UrlUtils.openWithSystemBrowser(
                      'https://getlantern.org/bypass-lists');
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
