import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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

// Widget to display and manage split tunneling apps
@RoutePage(name: 'AppsSplitTunneling')
class AppsSplitTunneling extends HookConsumerWidget {
  const AppsSplitTunneling({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One key per index letter, kept across rebuilds so the alphabet bar can
    // scroll to the first installed app of that letter.
    final letterKeys = useMemoized(() => <String, GlobalKey>{});
    // Letter whose first installed app is at or above the top of the list.
    final currentLetter = useState<String?>(null);
    // The index bar hangs from the "Installed Apps" header: it follows the
    // header while that scrolls and pins to the top once the header is gone.
    final installedHeaderKey = useMemoized(GlobalKey.new);
    final scrollViewKey = useMemoized(GlobalKey.new);
    final indexBarTop = useState(0.0);
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
    final appsByLetter = groupAppsByLetter(filteredDisabled);
    final indexLetters = appsByLetter.keys.toList();
    final showIndexBar = indexLetters.length > 1;

    /// Picks the letter at the top of the viewport from the positions of the
    /// letter headers. Rows are all laid out (the inner lists are
    /// shrink-wrapped), so every key that is present has a render box.
    void updateCurrentLetter() {
      final viewport = scrollViewKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox) return;

      final header = installedHeaderKey.currentContext?.findRenderObject();
      if (header is RenderBox && header.attached) {
        final top = header
            .localToGlobal(Offset.zero, ancestor: viewport)
            .dy
            .clamp(0.0, viewport.size.height);
        if (top != indexBarTop.value) {
          indexBarTop.value = top;
        }
      }

      String? best;
      var bestDy = double.negativeInfinity;
      String? first;
      var firstDy = double.infinity;
      for (final letter in indexLetters) {
        final box = letterKeys[letter]?.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached) continue;
        final dy = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        // Small tolerance so the row that ensureVisible aligns flush with the
        // top still counts as the current letter.
        if (dy <= 8 && dy > bestDy) {
          best = letter;
          bestDy = dy;
        }
        if (dy < firstDy) {
          first = letter;
          firstDy = dy;
        }
      }
      final next = best ?? first;
      if (next != currentLetter.value) {
        currentLetter.value = next;
      }
    }

    // Measure after layout so the bar is placed correctly before any scroll.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => updateCurrentLetter(),
      );
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
      body: Stack(
        // The index bar sits in the screen's side margin, over the edge of the
        // padded body, so the cards keep their normal width and stay centered.
        clipBehavior: Clip.none,
        children: [
          Padding(
            // Left edge keeps the screen's 16px padding; the right edge makes
            // room for the index bar, like the reference design.
            padding: EdgeInsets.only(right: showIndexBar ? 12 : 0),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                updateCurrentLetter();
                return false;
              },
              child: CustomScrollView(
                key: scrollViewKey,
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
                                    await notifier.deselectApps(
                                      filteredEnabled,
                                    );
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
                                onToggle: () => onTapAddApp(ctx, notifier, app),
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
            Positioned(
              top: indexBarTop.value + 10,
              bottom: 0,
              // Keep a small margin from the screen edge.
              right: -defaultPadding.right + 6,
              child: AlphabetIndexBar(
                letters: indexLetters,
                // Before any scroll, the top of the list is the first letter.
                currentLetter: currentLetter.value ?? indexLetters.firstOrNull,
                onLetterSelected: scrollToLetter,
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
          notifier.toggleApp(app);
        },
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
              onPressed: onToggle!,
            ),
        ],
      ),
    );
  }
}
