import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/provider/app_icon_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends ConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final notifier = ref.read(splitTunnelingAppsProvider.notifier);

    final enabledAppsAsync = ref.watch(splitTunnelingAppsProvider);
    final enabledApps = enabledAppsAsync.value ?? const <AppData>{};

    final allApps = dedupeAndSortApps(
      (ref.watch(appsDataProvider).value ?? const <AppData>[]).where(
        (a) => Platform.isAndroid || Platform.isIOS
            ? (a.iconPath.isNotEmpty || a.iconBytes != null)
            : true,
      ),
    );

    bool matchesSearch(AppData a) =>
        searchQuery.isEmpty ||
        a.name.toLowerCase().contains(searchQuery.toLowerCase());

    final enabledIds = enabledApps.map(normalizedAppId).toSet();
    final filteredEnabled = dedupeAndSortApps(enabledApps.where(matchesSearch));

    final filteredDisabled = allApps
        .where((a) => !enabledIds.contains(normalizedAppId(a)))
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
                            await notifier.deselectApps(filteredEnabled);
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
                                    onPressed: () => onTapSelectAll(
                                      ctx,
                                      notifier,
                                      filteredDisabled,
                                    ),
                                  ),
                                );
                              }
                              final app = filteredDisabled[i - 1];
                              return AppRow(
                                app: app,
                                enabled: false,
                                onToggle: () => onTapAddApp(ctx, notifier, app),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Show info dialog for first time user
  Future<void> onTapAddApp(
    BuildContext context,
    SplitTunnelingApps notifier,
    AppData app,
  ) async {
    if (app.isBrowser) {
      await AppDialog.browserBypassWarningDialog(
        context: context,
        browserName: app.name,
        onAddAnyway: () => notifier.toggleApp(app),
      );
      return;
    }
    final storage = sl<LocalStorageService>();
    if (!storage.hasSeenBypassAppDialog) {
      unawaited(storage.markBypassAppDialogSeen());
      await AppDialog.show(
        context: context,
        header: Center(child: AppImage(path: AppImagePaths.info, height: 40)),
        centeredTitle: true,
        title: 'bypass_app_first_time_title'.i18n,
        body: 'bypass_app_first_time_body'.i18n.fill([app.name]),
        primaryLabel: 'add'.i18n,
        onPrimaryPressed: () => notifier.toggleApp(app),
        secondaryLabel: 'cancel'.i18n,
      );
      return;
    }
    notifier.toggleApp(app);
  }

  /// Warn when Select All would put browsers on the bypass list
  Future<void> onTapSelectAll(
    BuildContext context,
    SplitTunnelingApps notifier,
    List<AppData> apps,
  ) async {
    final browsers = apps.where((a) => a.isBrowser).toList();
    if (browsers.isEmpty) {
      await notifier.selectApps(apps);
      return;
    }
    await _showSelectAllBypassWarning(
      context: context,
      browserName: browsers.first.name,
      onAddAllExceptBrowsers: () =>
          notifier.selectApps(apps.where((a) => !a.isBrowser).toList()),
      onAddAllAnyway: () => notifier.selectApps(apps),
    );
  }
}

/// Warning shown when "Select All" would add browsers to the bypass list
Future<void> _showSelectAllBypassWarning({
  required BuildContext context,
  required String browserName,
  required VoidCallback onAddAllExceptBrowsers,
  required VoidCallback onAddAllAnyway,
}) {
  final textTheme = Theme.of(context).textTheme;
  return AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: size24),
        Center(child: AppImage(path: AppImagePaths.warning, height: 45)),
        SizedBox(height: size24),
        Text(
          'bypass_all_warning_title'.i18n,
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'bypass_all_warning_body'.i18n.fill([browserName]),
          style: textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
            height: 23 / 16,
          ),
        ),
      ],
    ),
    action: [
      PrimaryButton(
        label: 'add_all_except_browsers'.i18n,
        onPressed: () {
          appRouter.pop();
          onAddAllExceptBrowsers();
        },
      ),
      SecondaryButton(
        label: 'add_all_anyway'.i18n,
        onPressed: () {
          appRouter.pop();
          onAddAllAnyway();
        },
      ),
      Center(
        child: AppTextButton(
          label: 'cancel'.i18n,
          textColor: context.textPrimary,
          onPressed: () => appRouter.pop(),
        ),
      ),
    ],
  );
}

class AppRow extends ConsumerWidget {
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
      id: normalizedAppId(app),
      iconPath: app.iconPath,
      appPath: app.appPath,
      existingBytes: app.iconBytes,
    );
    final iconAsync = ref.watch(appIconBytesProvider(key));

    Widget iconWidget() {
      if (app.iconBytes != null && app.iconBytes!.isNotEmpty) {
        return Image.memory(
          app.iconBytes!,
          width: 24,
          height: 24,
          errorBuilder: (_, error, stackTrace) =>
              Icon(Icons.apps, size: 24, color: context.textDisabled),
        );
      }
      if (!Platform.isWindows &&
          app.iconPath.isNotEmpty &&
          !app.iconPath.toLowerCase().endsWith('.icns')) {
        return Image.file(
          File(app.iconPath),
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) =>
              Icon(Icons.apps, size: 24, color: context.textDisabled),
        );
      }
      return iconAsync.maybeWhen(
        data: (bytes) {
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              width: 24,
              height: 24,
              errorBuilder: (_, error, stackTrace) =>
                  Icon(Icons.apps, size: 24, color: context.textDisabled),
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
