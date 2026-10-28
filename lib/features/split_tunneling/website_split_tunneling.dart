import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';
import 'package:lantern/features/split_tunneling/website_domain_input.dart';

@RoutePage(name: 'WebsiteSplitTunneling')
class WebsiteSplitTunneling extends HookConsumerWidget {
  const WebsiteSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(
        ref.read(splitTunnelingWebsitesProvider.notifier).refreshFromCore(),
      );
      return null;
    }, const []);

    final textTheme = Theme.of(context).textTheme;
    final searchQuery = ref.watch(searchQueryProvider);

    final snapshot = ref.watch(splitTunnelProvider).value;
    final websites = ref.watch(splitTunnelingWebsitesProvider);
    final enabledWebsites = websites.value ?? const <Website>{};
    matchesSearch(website) =>
        searchQuery.isEmpty ||
        website.displayDomain.toLowerCase().contains(searchQuery.toLowerCase());
    final enabledList = enabledWebsites.where(matchesSearch).toList()
      ..sort(
        (a, b) => a.domain.toLowerCase().compareTo(b.domain.toLowerCase()),
      );

    return BaseScreen(
      title: 'website_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'website_split_tunneling'.i18n,
        hintText: 'search_websites'.i18n,
      ),
      body: CustomScrollView(
        key: const Key('split_tunneling.website.screen'),
        slivers: [
          SliverToBoxAdapter(
            child: Focus(autofocus: true, child: WebsiteDomainInput()),
          ),
          SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
          SliverToBoxAdapter(child: DividerSpace()),
          SliverToBoxAdapter(child: SizedBox(height: defaultSize)),
          SliverToBoxAdapter(
            child: SectionLabel(
              (snapshot?.policy == SplitTunnelPolicy.includeOnly
                      ? 'websites_using_vpn'
                      : 'websites_bypassing_vpn')
                  .i18n
                  .fill([snapshot?.websiteCount ?? enabledWebsites.length]),
            ),
          ),
          SliverToBoxAdapter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: websites.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('split_tunnel_load_failed'.i18n),
                    )
                  : websites.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : enabledList.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'no_websites_selected'.i18n,
                        style: textTheme.bodyLarge!.copyWith(
                          color: context.textPrimary,
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
                          onToggle: () async {
                            final failure = await ref
                                .read(splitTunnelingWebsitesProvider.notifier)
                                .removeWebsite(website);
                            if (!context.mounted || failure == null) {
                              return;
                            }
                            context.showSnackBar(failure.localizedErrorMessage);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class WebsiteRow extends StatelessWidget {
  final Website website;
  final Future<void> Function() onToggle;

  const WebsiteRow({super.key, required this.website, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final normalizedDomain = website.displayDomain.toLowerCase();
    return AppTile(
      tileKey: Key('split_tunneling.website.row.$normalizedDomain'),
      minHeight: 45,
      contentPadding: EdgeInsets.only(left: 16),
      label: website.displayDomain,
      tileTextStyle: AppTextStyles.labelLarge.copyWith(
        color: context.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      trailing: AppIconButton(
        key: Key('split_tunneling.website.remove.$normalizedDomain'),
        path: AppImagePaths.close,
        onPressed: () => unawaited(onToggle()),
      ),
    );
  }
}
