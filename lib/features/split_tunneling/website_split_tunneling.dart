import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/split_tunneling/website.dart';
import 'package:lantern/core/split_tunneling/website_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/section_label.dart';
import 'package:lantern/features/split_tunneling/website_bypass_input.dart';

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchEnabled = useState(false);
    final searchQuery = ref.watch(searchQueryProvider);

    final websites = ref.watch(splitTunnelingWebsitesProvider);

    final enabledWebsites = websites.where((website) {
      final matchesSearch = searchQuery.isEmpty ||
          website.domain.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesSearch;
    }).toSet();

    return BaseScreen(
      title: 'website_split_tunneling'.i18n,
      appBar: CustomAppBar(
        title: searchEnabled.value
            ? AppSearchBar(
                hintText: 'search_websites'.i18n,
              )
            : 'website_split_tunneling'.i18n,
        actionsPadding: EdgeInsets.only(right: 24.0),
        actions: [
          AppIconButton(
            onPressed: () => searchEnabled.value = !searchEnabled.value,
            path: AppImagePaths.search,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: defaultSize),
          WebsiteBypassInput(),
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
            ...enabledWebsites.map((website) => _WebsiteRow(
                  website: website,
                  onToggle: () => ref
                      .read(splitTunnelingWebsitesProvider.notifier)
                      .toggleWebsite(website),
                )),
          ],
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }
}

class _WebsiteRow extends StatelessWidget {
  final Website website;
  final VoidCallback onToggle;

  const _WebsiteRow({
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
