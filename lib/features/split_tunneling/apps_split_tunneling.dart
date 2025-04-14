import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';

import 'package:lantern/core/split_tunneling/apps_data_provider.dart';
import 'package:lantern/core/split_tunneling/apps_notifier.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/section_label.dart';

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends HookConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);

    final allApps = ref.watch(appsDataProvider).value ?? [];
    final enabledApps = ref.watch(splitTunnelingAppsProvider);
    final installedApps = allApps.where((a) => a.iconPath.isNotEmpty).toSet();

    matchesSearch(app) =>
        searchQuery.isEmpty ||
        app.name.toLowerCase().contains(searchQuery.toLowerCase());

    final enabledAppNames =
        enabledApps.map((a) => a.name.toLowerCase()).toSet();

    final enabledList = enabledApps.where(matchesSearch).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final disabledApps = installedApps.where((app) {
      final isDisabled = !enabledAppNames.contains(app.name.toLowerCase());
      return matchesSearch(app) && isDisabled;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return BaseScreen(
      title: 'apps_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'apps_split_tunneling'.i18n,
        hintText: 'search_apps'.i18n,
      ),
      body: CustomScrollView(
        slivers: [
          if (enabledApps.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionLabel(
                'apps_bypassing_vpn'.i18n.fill([enabledApps.length]),
              ),
            ),
            SliverList.list(
              children: enabledList
                  .map((app) => AppRow(
                        app: app.copyWith(isEnabled: true),
                        onToggle: () => ref
                            .read(splitTunnelingAppsProvider.notifier)
                            .toggleApp(app),
                      ))
                  .toList(),
            ),
          ],
          if (disabledApps.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionLabel('installed_apps'.i18n),
            ),
            SliverList.list(
              children: disabledApps
                  .map((app) => AppRow(
                        app: app,
                        onToggle: () => ref
                            .read(splitTunnelingAppsProvider.notifier)
                            .toggleApp(app),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class AppRow extends StatelessWidget {
  final AppData app;
  final VoidCallback? onToggle;

  const AppRow({
    super.key,
    required this.app,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon + App Name
          Row(
            children: [
              if (app.iconPath.isNotEmpty)
                Image.file(
                  File(app.iconPath),
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                )
              else
                Icon(Icons.apps, size: 24, color: AppColors.gray6),
              const SizedBox(width: 12),
              Text(
                app.name.replaceAll(".app", ""),
                style: AppTestStyles.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray9,
                ),
              ),
            ],
          ),
          // Toggle Button
          if (onToggle != null)
            AppIconButton(
              path: app.isEnabled ? AppImagePaths.minus : AppImagePaths.plus,
              onPressed: onToggle!,
            ),
        ],
      ),
    );
  }
}
