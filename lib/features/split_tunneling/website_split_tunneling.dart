import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/website_domain_input.dart';

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);

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
            child: Focus(
              autofocus: true,
              child: WebsiteDomainInput(),
            ),
          ),
          SliverToBoxAdapter(
            child: AppTile(
              icon: AppImagePaths.bypassList,
              label: 'default_bypass'.i18n,
              trailing: AppIconButton(
                path: AppImagePaths.arrowForward,
                onPressed: () => {},
              ),
            ),
          ),
          // Websites bypassing the VPN
          if (enabledWebsites.isNotEmpty)
            SliverToBoxAdapter(
              child: SectionLabel(
                'websites_bypassing_vpn'.i18n.fill([enabledWebsites.length]),
              ),
            ),

          // List of enabled websites
          SliverList.list(
            children: enabledList
                .map((website) => WebsiteRow(
                      website: website,
                      onToggle: () => ref
                          .read(splitTunnelingWebsitesProvider.notifier)
                          .removeWebsite(website),
                    ))
                .toList(),
          ),
        ],
      ),
    );
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
      label: website.domain,
      tileTextStyle: AppTestStyles.labelLarge.copyWith(
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
