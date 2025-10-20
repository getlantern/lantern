import 'dart:io';
import 'dart:typed_data';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends HookConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final notifier = ref.read(splitTunnelingAppsProvider.notifier);
    final enabledApps = ref.watch(splitTunnelingAppsProvider);
    final allApps = (ref.watch(appsDataProvider).value ?? [])
        .where((a) => a.iconPath.isNotEmpty || a.iconBytes != null)
        .where((a) => a.bundleId != AppSecrets.lanternPackageName)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final installedApps = allApps;

    bool matchesSearch(AppData a) =>
        searchQuery.isEmpty ||
        a.name.toLowerCase().contains(searchQuery.toLowerCase());

    final filteredEnabled = enabledApps.where(matchesSearch).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final filteredDisabled = installedApps
        .where((a) => !enabledApps.any((e) => e.name == a.name))
        .where(matchesSearch)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return BaseScreen(
      title: 'apps_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'apps_split_tunneling'.i18n,
        hintText: 'search_apps'.i18n,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Row(
              children: [
                SectionLabel(
                  'apps_bypassing_vpn'.i18n.fill([enabledApps.length]),
                ),
                const Spacer(),
              ],
            ),
          ),
          if (enabledApps.isEmpty)
            SliverToBoxAdapter(
              child: AppCard(
                padding: EdgeInsets.all(0),
                child: AppTile(
                  label: 'no_apps_selected'.i18n,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: AppCard(
                child: ListView.separated(
                  padding: EdgeInsets.all(0),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredEnabled.length + 1,
                  separatorBuilder: (_, __) =>
                      DividerSpace(padding: EdgeInsets.zero),
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return AppTile(
                        minHeight: 40,
                        contentPadding: EdgeInsets.zero,
                        label: '',
                        trailing: AppTextButton(
                          label: 'deselect_all'.i18n,
                          fontSize: 14,
                          onPressed: () {
                            notifier.deselectAllApps();
                          },
                        ),
                      );
                    }
                    final app = filteredEnabled[i - 1];
                    return AppRow(
                      app: app.copyWith(isEnabled: true),
                      onToggle: () => notifier.toggleApp(app),
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: SectionLabel('installed_apps'.i18n)),
          SliverToBoxAdapter(
            child: AppCard(
              child: filteredDisabled.isEmpty
                  ? AppTile(minHeight: 40, label: 'no_apps_selected'.i18n)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredDisabled.length + 1,
                      separatorBuilder: (_, __) =>
                          DividerSpace(padding: EdgeInsets.zero),
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return AppTile(
                            minHeight: 40,
                            contentPadding: EdgeInsets.zero,
                            label: '',
                            trailing: AppTextButton(
                              label: 'select_all'.i18n,
                              fontSize: 14,
                              onPressed: () {
                                notifier.selectAllApps();
                              },
                            ),
                          );
                        }
                        final app = filteredDisabled[i - 1];
                        return AppRow(
                          app: app,
                          onToggle: () => notifier.toggleApp(app),
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

class AppRow extends StatelessWidget {
  final AppData app;
  final VoidCallback? onToggle;

  const AppRow({
    super.key,
    required this.app,
    this.onToggle,
  });

  Widget buildAppIcon(AppData appData) {
    Uint8List? iconBytes = appData.iconBytes;
    if (iconBytes != null) {
      return Image.memory(iconBytes, width: 24, height: 24);
    } else if (appData.iconPath.isNotEmpty) {
      return Image.file(
        File(app.iconPath),
        width: 24,
        height: 24,
        fit: BoxFit.cover,
      );
    }

    // fallback
    return Icon(Icons.apps, size: 24, color: AppColors.gray6);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54.h,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                buildAppIcon(app),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.name.replaceAll(".app", ""),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.gray9,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
