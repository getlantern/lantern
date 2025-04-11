import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/widgets/website_bypass_input.dart';
import 'package:lantern/features/split_tunneling/widgets/website_row.dart';

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);

    final websites = ref.watch(splitTunnelingWebsitesProvider);

    final enabledWebsites = websites.where((website) {
      final matchesSearch = searchQuery.isEmpty ||
          website.domain.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesSearch;
    }).toSet();

    return BaseScreen(
      title: 'website_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'website_split_tunneling'.i18n,
        hintText: 'search_websites'.i18n,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          Focus(
            autofocus: true,
            child: WebsiteDomainInput(),
          ),
          SizedBox(height: defaultSize),
          AppTile(
            icon: AppImagePaths.bypassList,
            label: 'default_bypass'.i18n,
            trailing: AppIconButton(
              path: AppImagePaths.arrowForward,
              onPressed: () => {},
            ),
          ),
          SizedBox(height: defaultSize),
          // Websites bypassing the VPN
          if (enabledWebsites.isNotEmpty) ...[
            SectionLabel(
              'websites_bypassing_vpn'.i18n.fill([enabledWebsites.length]),
            ),
            ...enabledWebsites.map((website) => WebsiteRow(
                  website: website,
                  onToggle: () => ref
                      .read(splitTunnelingWebsitesProvider.notifier)
                      .removeWebsite(website),
                )),
          ],
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }
}
