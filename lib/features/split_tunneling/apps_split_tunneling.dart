import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/provider/app_icon_provider.dart';
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

    final enabledAppsAsync = ref.watch(splitTunnelingAppsProvider);
    final enabledApps = enabledAppsAsync.value ?? const <AppData>{};

    final allApps = _dedupeAndSortApps(
      (ref.watch(appsDataProvider).value ?? const <AppData>[])
          .where(
            (a) => Platform.isAndroid || Platform.isIOS
                ? (a.iconPath.isNotEmpty || a.iconBytes != null)
                : true,
          )
          .where((a) => !_isLanternApp(a)),
    );

    bool matchesSearch(AppData a) =>
        searchQuery.isEmpty ||
        a.name.toLowerCase().contains(searchQuery.toLowerCase());

    final enabledIds = enabledApps.map(_normalizedStableAppId).toSet();
    final filteredEnabled = _dedupeAndSortApps(
      enabledApps.where(matchesSearch),
    );

    final filteredDisabled = allApps
        .where((a) => !enabledIds.contains(_normalizedStableAppId(a)))
        .where(matchesSearch)
        .toList();

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
                child: AppTile(label: 'no_apps_selected'.i18n),
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
                  separatorBuilder: (_, separatorIndex) =>
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
                          onPressed: () async {
                            await notifier.deselectAllApps();
                          },
                        ),
                      );
                    }
                    final app = filteredEnabled[i - 1];
                    return AppRow(
                      app: app,
                      enabled: true,
                      onToggle: () => notifier.toggleApp(app),
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: SectionLabel('installed_apps'.i18n)),
          SliverToBoxAdapter(
            child: allApps.isEmpty
                ? AppCard(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Center(child: LoadingIndicator()),
                  )
                : AppCard(
                    child: filteredDisabled.isEmpty
                        ? AppTile(minHeight: 40, label: 'no_apps_selected'.i18n)
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredDisabled.length + 1,
                            separatorBuilder: (_, separatorIndex) =>
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
                                enabled: false,
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

class AppRow extends HookConsumerWidget {
  final AppData app;
  final bool enabled;
  final VoidCallback? onToggle;

  const AppRow({
    super.key,
    required this.enabled,
    required this.app,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = AppIconKey(
      id: _normalizedStableAppId(app),
      iconPath: app.iconPath,
      appPath: app.appPath,
      existingBytes: app.iconBytes,
    );

    final iconAsync = ref.watch(appIconBytesProvider(key));

    Widget iconWidget() {
      return iconAsync.maybeWhen(
        data: (bytes) {
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(bytes, width: 24, height: 24);
          }
          if (app.iconPath.isNotEmpty &&
              !app.iconPath.toLowerCase().endsWith('.icns')) {
            return Image.file(
              File(app.iconPath),
              width: 24,
              height: 24,
              fit: BoxFit.cover,
            );
          }
          return Icon(Icons.apps, size: 24, color: context.textDisabled);
        },
        orElse: () => Icon(Icons.apps, size: 24, color: context.textDisabled),
      );
    }

    return SizedBox(
      height: 44.h,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                iconWidget(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.name.replaceAll(".app", ""),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onToggle != null)
            AppIconButton(
              path: enabled ? AppImagePaths.minus : AppImagePaths.plus,
              onPressed: onToggle!,
            ),
        ],
      ),
    );
  }
}

String _normalizedStableAppId(AppData app) {
  final id = stableAppId(app).trim();
  if (Platform.isWindows) {
    return id.toLowerCase();
  }
  return id;
}

bool _isLanternApp(AppData app) {
  final packageName = AppSecrets.lanternPackageName.toLowerCase();
  final bundleId = app.bundleId.trim().toLowerCase();
  final appName = app.name.trim().toLowerCase();
  final appPath = app.appPath.trim().toLowerCase();
  final appExe = appPath.split(RegExp(r'[\\/]+')).last;

  return bundleId == packageName ||
      appName == 'lantern' ||
      appExe == 'lantern' ||
      appExe == 'lantern.exe';
}

AppData _preferRicherApp(AppData? current, AppData candidate) {
  if (current == null) {
    return candidate;
  }

  final currentHasIcon =
      (current.iconBytes?.isNotEmpty ?? false) || current.iconPath.isNotEmpty;
  final candidateHasIcon =
      (candidate.iconBytes?.isNotEmpty ?? false) ||
      candidate.iconPath.isNotEmpty;

  if (candidateHasIcon && !currentHasIcon) {
    return candidate;
  }
  if (currentHasIcon && !candidateHasIcon) {
    return current;
  }
  if (candidate.lastUpdateTime > current.lastUpdateTime) {
    return candidate;
  }
  if (current.name.trim().isEmpty && candidate.name.trim().isNotEmpty) {
    return candidate;
  }
  return current;
}

List<AppData> _dedupeAndSortApps(Iterable<AppData> apps) {
  final byId = <String, AppData>{};
  for (final app in apps) {
    final id = _normalizedStableAppId(app);
    if (id.isEmpty) {
      continue;
    }
    byId[id] = _preferRicherApp(byId[id], app);
  }

  final out = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return out;
}
