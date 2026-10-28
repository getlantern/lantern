import 'dart:io';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/split_tunneling/alphabet_index_bar.dart';
import 'package:lantern/features/split_tunneling/provider/app_icon_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/search_query.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
import 'package:lantern/features/split_tunneling/windows_executable_picker.dart';

/// Extra width taken from the cards, on the right, for the index bar.
const _indexBarGutter = 12.0;

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends HookConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One key per index letter, kept across rebuilds so the alphabet bar can
    // scroll to the first installed app of that letter.
    final letterKeys = useMemoized(() => <String, GlobalKey>{});
    // The index bar hangs from the "Installed Apps" header: it follows the
    // header while that scrolls and pins to the top once the header is gone.
    final installedHeaderKey = useMemoized(GlobalKey.new);
    final scrollViewKey = useMemoized(GlobalKey.new);
    final indexBarTop = useState(0.0);
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
    final notifier = ref.read(splitTunnelingAppsProvider.notifier);

    final snapshot = ref.watch(splitTunnelProvider).value;
    final bypass = snapshot?.policy != SplitTunnelPolicy.includeOnly;
    final enabledAppsAsync = ref.watch(splitTunnelingAppsProvider);
    final enabledApps = enabledAppsAsync.value ?? const <AppData>{};

    final installedApps = ref.watch(appsDataProvider);
    final allApps = dedupeAndSortApps(
      (installedApps.value ?? const <AppData>[]).where(
        (a) => Platform.isAndroid || Platform.isIOS
            ? (a.iconPath.isNotEmpty || a.iconBytes != null)
            : true,
      ),
    );

    bool matchesSearch(AppData a) =>
        searchQuery.isEmpty ||
        a.name.toLowerCase().contains(searchQuery) ||
        (Platform.isWindows && a.appPath.toLowerCase().contains(searchQuery));

    final enabledIds = enabledApps.map(normalizedAppId).toSet();
    final filteredEnabled = enabledApps.where(matchesSearch).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final filteredDisabled = allApps
        .where((a) => !enabledIds.contains(normalizedAppId(a)))
        .where(matchesSearch)
        .toList();
    final appsByLetter = groupAppsByLetter(filteredDisabled);
    final indexLetters = appsByLetter.keys.toList();
    final showIndexBar = indexLetters.length > 1;

    void updateIndexBarTop() {
      final viewport = scrollViewKey.currentContext?.findRenderObject();
      final header = installedHeaderKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox || header is! RenderBox || !header.attached) {
        return;
      }
      final top = math.max(
        0.0,
        header.localToGlobal(Offset.zero, ancestor: viewport).dy,
      );
      if (top != indexBarTop.value) {
        indexBarTop.value = top;
      }
    }

    // Measure after layout so the bar is placed correctly before any scroll.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) => updateIndexBarTop());
      return null;
    });

    Future<void> scrollToLetter(String letter) async {
      final target = letterKeys[letter]?.currentContext;
      if (target == null) return;
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
      );
    }

    return BaseScreen(
      title: 'apps_split_tunneling'.i18n,
      appBar: AppSearchBar(
        ref: ref,
        title: 'apps_split_tunneling'.i18n,
        hintText: 'search_apps'.i18n,
      ),
      // The screen pads itself so the index bar can live in the right-hand
      // gutter, inside the Stack, where it can be tapped.
      padded: false,
      body: Stack(
        children: [
          Padding(
            padding: defaultPadding.copyWith(
              right: showIndexBar
                  ? defaultPadding.right + _indexBarGutter
                  : defaultPadding.right,
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                updateIndexBarTop();
                return false;
              },
              child: CustomScrollView(
                key: scrollViewKey,
                slivers: [
                  SliverToBoxAdapter(
                    child: Row(
                      children: [
                        SectionLabel(
                          (bypass ? 'apps_bypassing_vpn' : 'apps_using_vpn')
                              .i18n
                              .fill([snapshot?.appCount ?? enabledApps.length]),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  if (enabledAppsAsync.hasError)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Text('split_tunnel_load_failed'.i18n),
                          AppTextButton(
                            label: 'retry'.i18n,
                            onPressed: () => ref
                                .read(splitTunnelProvider.notifier)
                                .refresh(),
                          ),
                        ],
                      ),
                    )
                  else if (enabledAppsAsync.isLoading)
                    const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (enabledApps.isEmpty)
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
                                  key: const Key('split_tunneling.apps.clear'),
                                  label: 'split_tunnel_clear'.i18n,
                                  fontSize: 14,
                                  onPressed: () async {
                                    final failure = await notifier
                                        .deselectAllApps();
                                    if (context.mounted && failure != null) {
                                      context.showSnackBarError(
                                        failure.localizedErrorMessage,
                                      );
                                    }
                                  },
                                ),
                              );
                            }
                            final app = filteredEnabled[i - 1];
                            return AppRow(
                              key: ValueKey(
                                'split-tunnel-app:${splitTunnelAppRowId(app)}',
                              ),
                              app: app,
                              enabled: true,
                              onToggle: () async {
                                final failure = await notifier.toggleApp(app);
                                if (context.mounted && failure != null) {
                                  context.showSnackBarError(
                                    failure.localizedErrorMessage,
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: Row(
                      key: installedHeaderKey,
                      children: [
                        SectionLabel('installed_apps'.i18n),
                        const Spacer(),
                        if (Platform.isWindows)
                          WindowsExecutablePicker(
                            confirmBypass: (context, app) async =>
                                !bypass || await confirmAppBypass(context, app),
                          ),
                      ],
                    ),
                  ),
                  if (installedApps.hasError)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Text('split_tunnel_load_failed'.i18n),
                          AppTextButton(
                            label: 'retry'.i18n,
                            onPressed: () => ref.invalidate(appsDataProvider),
                          ),
                        ],
                      ),
                    )
                  else if (installedApps.isLoading && !installedApps.hasValue)
                    SliverToBoxAdapter(
                      child: AppCard(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 48,
                        ),
                        child: Center(child: LoadingIndicator()),
                      ),
                    )
                  else if (filteredDisabled.isEmpty)
                    SliverToBoxAdapter(
                      child: AppCard(
                        child: AppTile(
                          minHeight: 40,
                          label: 'no_apps_selected'.i18n,
                        ),
                      ),
                    )
                  else
                    for (final entry in appsByLetter.entries) ...[
                      SliverToBoxAdapter(
                        child: SectionLabel(
                          entry.key,
                          key: letterKeys.putIfAbsent(entry.key, GlobalKey.new),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: AppCard(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entry.value.length,
                            separatorBuilder: (_, separatorIndex) =>
                                DividerSpace(padding: EdgeInsets.zero),
                            itemBuilder: (ctx, i) {
                              final app = entry.value[i];
                              return AppRow(
                                key: ValueKey(
                                  'split-tunnel-app:${splitTunnelAppRowId(app)}',
                                ),
                                app: app,
                                enabled: false,
                                onToggle: () => onTapAddApp(
                                  ctx,
                                  notifier,
                                  app,
                                  bypass: bypass,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ],
                ],
              ),
            ),
          ),
          if (showIndexBar)
            Positioned.fill(
              right: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottom = math.min(
                    defaultPadding.bottom,
                    constraints.maxHeight,
                  );
                  // Keep every letter reachable when the bypass list pushes the
                  // installed-apps header below the viewport.
                  final minHeight =
                      indexLetters.length * AlphabetIndexBar.minLetterHeight;
                  final maxTop = math.max(
                    0.0,
                    constraints.maxHeight - bottom - minHeight,
                  );
                  final top = math.min(
                    defaultPadding.top + indexBarTop.value + 10,
                    maxTop,
                  );
                  return Padding(
                    padding: EdgeInsets.only(top: top, bottom: bottom),
                    child: AlphabetIndexBar(
                      letters: indexLetters,
                      onLetterSelected: scrollToLetter,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static Future<bool> confirmAppBypass(
    BuildContext context,
    AppData app,
  ) async {
    final storage = sl<LocalStorageService>();
    if (!app.isBrowser && storage.hasSeenBypassAppDialog) return true;

    var confirmed = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    void confirm() {
      confirmed = context.mounted;
      navigator.pop();
    }

    await AppDialog.show(
      context: context,
      header: Center(
        child: AppImage(
          path: app.isBrowser ? AppImagePaths.warning : AppImagePaths.info,
          height: app.isBrowser ? 45 : 40,
        ),
      ),
      centeredTitle: true,
      title:
          (app.isBrowser
                  ? 'bypass_browser_warning_title'
                  : 'bypass_app_first_time_title')
              .i18n
              .fill([app.name]),
      body:
          (app.isBrowser
                  ? 'bypass_browser_warning_body'
                  : 'bypass_app_first_time_body')
              .i18n
              .fill([app.name]),
      primaryLabel: (app.isBrowser ? 'cancel' : 'add').i18n,
      dismissOnPrimary: app.isBrowser,
      onPrimaryPressed: app.isBrowser ? null : confirm,
      secondaryLabel: (app.isBrowser ? 'add_anyway' : 'cancel').i18n,
      dismissOnSecondary: !app.isBrowser,
      onSecondaryPressed: app.isBrowser ? confirm : null,
    );
    if (!confirmed || !context.mounted) return false;
    if (!app.isBrowser) await storage.markBypassAppDialogSeen();
    return context.mounted;
  }

  Future<void> onTapAddApp(
    BuildContext context,
    SplitTunnelingApps notifier,
    AppData app, {
    bool bypass = true,
  }) async {
    if (bypass && !await confirmAppBypass(context, app)) return;
    if (!context.mounted) return;
    final failure = await notifier.toggleApp(app);
    if (context.mounted && failure != null) {
      context.showSnackBarError(failure.localizedErrorMessage);
    }
  }
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

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 44.h),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                iconWidget(),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          app.name.replaceAll(".app", ""),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: context.textPrimary,
                          ),
                        ),
                        if (Platform.isWindows || app is StoredSplitTunnelApp)
                          Tooltip(
                            message: app is StoredSplitTunnelApp
                                ? (app as StoredSplitTunnelApp).selector
                                : app.appPath,
                            child: Text(
                              app is StoredSplitTunnelApp
                                  ? (app as StoredSplitTunnelApp).selector
                                  : app.appPath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onToggle != null)
            AppIconButton(
              key: ValueKey(
                'toggle-split-tunnel-app:${splitTunnelAppRowId(app)}',
              ),
              path: enabled ? AppImagePaths.minus : AppImagePaths.plus,
              onPressed: () {
                HapticFeedback.lightImpact();
                onToggle!();
              },
            ),
        ],
      ),
    );
  }
}
