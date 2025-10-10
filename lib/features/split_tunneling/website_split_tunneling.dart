import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/website.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';
import 'package:lantern/features/split_tunneling/website_domain_input.dart';

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final searchQuery = ref.watch(searchQueryProvider);
    final appSetting = ref.watch(appSettingNotifierProvider);

    final enabledWebsites = ref.watch(splitTunnelingWebsitesProvider);
    matchesSearch(website) =>
        searchQuery.isEmpty ||
        website.domain.toLowerCase().contains(searchQuery.toLowerCase());
    final enabledList = enabledWebsites.where(matchesSearch).toList()
      ..sort(
          (a, b) => a.domain.toLowerCase().compareTo(b.domain.toLowerCase()));

    return BaseScreen(
      title: 'website_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'website_split_tunneling'.i18n,
        hintText: 'search_websites'.i18n,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Focus(autofocus: true, child: WebsiteDomainInput()),
          ),
          SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
          SliverToBoxAdapter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                onPressed: () {
                  appRouter.push(DefaultBypassLists());
                },
                contentPadding: EdgeInsets.only(left: 16),
                icon: AppImagePaths.bypassList,
                label: 'default_bypass'.i18n,
                trailing: AppIconButton(
                  path: AppImagePaths.arrowForward,
                  onPressed: () => appRouter.push(DefaultBypassLists()),
                ),
              ),
            ),
          ),
          if (appSetting.bypassList.isNotEmpty) ...{
            SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
            SliverToBoxAdapter(
                child: SectionLabel('enabled_bypass_lists'
                    .i18n
                    .fill([appSetting.bypassList.length]))),
            SliverToBoxAdapter(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                    itemCount: appSetting.bypassList.length,
                    shrinkWrap: true,
                    separatorBuilder: (context, index) =>
                        DividerSpace(padding: EdgeInsets.zero),
                    itemBuilder: (context, index) {
                      final bypassList = appSetting.bypassList[index];
                      return AppTile(
                        contentPadding: EdgeInsets.only(left: 16),
                        label: '${bypassList.value}_bypass_list'.i18n,
                        subtitle: Text(
                          '${bypassList.value}_bypass_desc'.i18n,
                          style: textTheme.labelMedium!
                              .copyWith(color: AppColors.gray7),
                        ),
                        trailing: AppIconButton(
                          path: AppImagePaths.close,
                          onPressed: () => removeBypassList(ref, bypassList),
                        ),
                      );
                    }),
              ),
            )
          },
          SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
          SliverToBoxAdapter(child: DividerSpace()),
          SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
          SliverToBoxAdapter(
            child: SectionLabel(
              'websites_bypassing_vpn'.i18n.fill([enabledWebsites.length]),
            ),
          ),
          SliverToBoxAdapter(
            child: AppCard(
                padding: EdgeInsets.zero,
                child: enabledList.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'no_websites_selected'.i18n,
                          style: textTheme.bodyLarge!.copyWith(
                            color: AppColors.gray9,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        separatorBuilder: (context, index) =>
                            DividerSpace(padding: EdgeInsets.zero),
                        itemCount: enabledList.length,
                        itemBuilder: (context, index) {
                          final website = enabledList[index];
                          return WebsiteRow(
                            website: website,
                            onToggle: () => ref
                                .read(splitTunnelingWebsitesProvider.notifier)
                                .removeWebsite(website),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  void removeBypassList(WidgetRef ref, BypassListOption bypassList) {
    final appSetting = ref.read(appSettingNotifierProvider);
    final websiteNr = ref.read(splitTunnelingWebsitesProvider.notifier);
    final selectedBypassList = appSetting.bypassList;
    selectedBypassList.remove(bypassList);
    websiteNr.updateByPassList(selectedBypassList);
  }
}

class WebsiteRow extends StatelessWidget {
  final Website website;
  final VoidCallback onToggle;

  const WebsiteRow({
    super.key,
    required this.website,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      minHeight: 45,
      contentPadding: EdgeInsets.only(left: 16),
      label: website.domain,
      tileTextStyle: AppTextStyles.labelLarge.copyWith(
        color: AppColors.gray8,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      trailing: AppIconButton(
        path: AppImagePaths.close,
        onPressed: onToggle,
      ),
    );
  }
}
