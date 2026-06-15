import 'dart:async';
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
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

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
    final searchQuery = ref.watch(searchQueryProvider);
    final notifier = ref.read(splitTunnelingAppsProvider.notifier);

    final enabledAppsAsync = ref.watch(splitTunnelingAppsProvider);
    final enabledApps = enabledAppsAsync.value ?? const <AppData>{};
    final directConnectionApps =
        AppBuildInfo.stealthDirectConnectionApps && PlatformUtils.isAndroid;
    final title = directConnectionApps
        ? 'direct_connection_apps'.i18n
        : 'apps_split_tunneling'.i18n;
    void showReconnectNoticeIfNeeded(bool changed) {
      if (!changed ||
          !directConnectionApps ||
          ref.read(vpnProvider) != VPNStatus.connected ||
          !context.mounted) {
        return;
      }
      context.showSnackBar('changes_applied_after_restart'.i18n);
    }

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
      title: title,
      appBar: AppSearchBar(
        ref: ref,
        title: title,
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
                          directConnectionApps
                              ? 'apps_using_direct_connection'.i18n.fill([
                                  enabledApps.length,
                                ])
                              : 'apps_bypassing_vpn'.i18n.fill([
                                  enabledApps.length,
                                ]),
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
                                    final changed = await notifier.deselectApps(
                                      filteredEnabled,
                                    );
                                    showReconnectNoticeIfNeeded(changed);
                                  },
                                ),
                              );
                            }
                            final app = filteredEnabled[i - 1];
                            return AppRow(
                              app: app,
                              enabled: true,
                              onToggle: () async {
                                final changed = await notifier.toggleApp(app);
                                showReconnectNoticeIfNeeded(changed);
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
                        if (filteredDisabled.isNotEmpty)
                          AppTextButton(
                            label: 'select_all'.i18n,
                            fontSize: 14,
                            onPressed: () => onTapSelectAll(
                              context,
                              notifier,
                              filteredDisabled,
                              showReconnectNoticeIfNeeded,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (allApps.isEmpty)
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
                                app: app,
                                enabled: false,
                                onToggle: () => onTapAddApp(
                                  ctx,
                                  notifier,
                                  app,
                                  showReconnectNoticeIfNeeded,
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

  /// Show info dialog for first time user
  Future<void> onTapAddApp(
    BuildContext context,
    SplitTunnelingApps notifier,
    AppData app,
    void Function(bool changed) onChanged,
  ) async {
    Future<void> toggle() async => onChanged(await notifier.toggleApp(app));
    if (app.isBrowser) {
      await AppDialog.browserBypassWarningDialog(
        context: context,
        browserName: app.name,
        onAddAnyway: toggle,
      );
      return;
    }
    final storage = sl<LocalStorageService>();
    if (!storage.hasSeenBypassAppDialog) {
      await AppDialog.show(
        context: context,
        header: Center(child: AppImage(path: AppImagePaths.info, height: 40)),
        centeredTitle: true,
        title: 'bypass_app_first_time_title'.i18n,
        body: 'bypass_app_first_time_body'.i18n.fill([app.name]),
        primaryLabel: 'add'.i18n,
        onPrimaryPressed: () {
          // Mark seen only on confirm; cancelling should show the
          // explainer again next time.
          unawaited(storage.markBypassAppDialogSeen());
          unawaited(toggle());
        },
        secondaryLabel: 'cancel'.i18n,
      );
      return;
    }
    await toggle();
  }

  /// Warn when Select All would put browsers on the bypass list
  Future<void> onTapSelectAll(
    BuildContext context,
    SplitTunnelingApps notifier,
    List<AppData> apps,
    void Function(bool changed) onChanged,
  ) async {
    Future<void> select(Iterable<AppData> toSelect) async =>
        onChanged(await notifier.selectApps(toSelect));
    final browsers = apps.where((a) => a.isBrowser).toList();
    if (browsers.isEmpty) {
      await select(apps);
      return;
    }
    await _showSelectAllBypassWarning(
      context: context,
      browserName: browsers.first.name,
      onAddAllExceptBrowsers: () => select(apps.where((a) => !a.isBrowser)),
      onAddAllAnyway: () => select(apps),
    );
  }
}

/// Warning shown when "Select All" would add browsers to the bypass list
Future<void> _showSelectAllBypassWarning({
  required BuildContext context,
  required String browserName,
  required Future<void> Function() onAddAllExceptBrowsers,
  required Future<void> Function() onAddAllAnyway,
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
        onPressed: () async {
          appRouter.pop();
          await onAddAllExceptBrowsers();
        },
      ),
      SecondaryButton(
        label: 'add_all_anyway'.i18n,
        onPressed: () async {
          appRouter.pop();
          await onAddAllAnyway();
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
