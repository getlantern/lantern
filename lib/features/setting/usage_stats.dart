import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_hooks/material_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide useTabController;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:lantern/core/models/usage_stats.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';
import 'package:lantern/features/setting/provider/usage_stats_notifier.dart';

/// How often the screen reloads the stats while it's on top and the app is
/// visible.
const usageStatsRefreshInterval = Duration(seconds: 10);

/// Whether the app can be seen. A desktop window that is visible but not
/// focused is inactive, and still counts.
bool _appVisible(AppLifecycleState? state) =>
    state == null ||
    state == AppLifecycleState.resumed ||
    state == AppLifecycleState.inactive;

/// Replaces the desktop window check in tests.
@visibleForTesting
Future<bool> Function()? debugWindowShown;

/// Whether the desktop window is on screen: not hidden (closed to the tray)
/// or minimized. Assumes it is if the window plugin can't say.
Future<bool> _windowShown() async {
  if (!PlatformUtils.isDesktop) return true;
  final override = debugWindowShown;
  if (override != null) return override();
  try {
    return AppWindow.instance.isShown;
  } catch (_) {
    return true;
  }
}

@RoutePage(name: 'UsageStatsScreen')
class UsageStatsScreen extends HookConsumerWidget {
  const UsageStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(usageStatsProvider);
    final tabController = useTabController(initialLength: 2);
    final allTime = useListenableSelector(
      tabController,
      () => tabController.index == 1,
    );

    // Reloads only while the screen can be seen: the timer stops while the
    // app is hidden, the desktop window is hidden or minimized, or another
    // route covers this one, and coming back reloads at once. Lifecycle and
    // window changes act at once rather than on a rebuild, since a hidden app
    // draws no frames.
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final routeCurrentRef = useRef(routeCurrent)..value = routeCurrent;
    // On desktop the window is checked on mount before the timer starts.
    final windowShown = useRef(!PlatformUtils.isDesktop);
    final timer = useRef<Timer?>(null);
    final mounted = useRef(false);
    void stop() {
      timer.value?.cancel();
      timer.value = null;
    }

    void refresh() =>
        unawaited(ref.read(usageStatsProvider.notifier).refresh());

    // A start reloads at once unless it comes with opening the screen, when
    // build loads the stats.
    void sync({bool reload = true}) {
      final visible =
          routeCurrentRef.value &&
          windowShown.value &&
          _appVisible(WidgetsBinding.instance.lifecycleState);
      if (!visible) return stop();
      if (timer.value != null) return;
      if (reload) refresh();
      timer.value = Timer.periodic(usageStatsRefreshInterval, (tick) async {
        // Closing the window to the tray can leave the app inactive, not
        // hidden, so each tick first checks the window is still shown.
        final shown = await _windowShown();
        // The screen may have stopped or restarted its timer meanwhile.
        if (!context.mounted || !identical(timer.value, tick)) return;
        if (!shown) {
          windowShown.value = false;
          return stop();
        }
        if (routeCurrentRef.value &&
            _appVisible(WidgetsBinding.instance.lifecycleState)) {
          refresh();
        }
      });
    }

    Future<void> recheckWindow({bool reload = true}) async {
      windowShown.value = await _windowShown();
      if (context.mounted) sync(reload: reload);
    }

    useOnAppLifecycleStateChange((_, _) {
      sync();
      unawaited(recheckWindow());
    });
    useEffect(() {
      if (!PlatformUtils.isDesktop) return null;
      void listener() => unawaited(recheckWindow());
      AppWindow.instance.changed.addListener(listener);
      unawaited(recheckWindow(reload: false));
      return () => AppWindow.instance.changed.removeListener(listener);
    }, const []);
    useEffect(() {
      sync(reload: mounted.value);
      mounted.value = true;
      return null;
    }, [routeCurrent]);
    useEffect(() => stop, const []);

    return BaseScreen(
      title: 'usage_stats'.i18n,
      body: statsAsync.when(
        // Retry after a failed load shows the spinner.
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: true,
        data: (stats) => _UsageStatsBody(
          stats: stats,
          allTime: allTime,
          tabController: tabController,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'usage_stats_load_failed'.i18n,
                key: const Key('usage_stats.error'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: context.textSecondary),
              ),
              const SizedBox(height: 8),
              AppTextButton(
                label: 'retry'.i18n,
                onPressed: () => ref.invalidate(usageStatsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageStatsBody extends HookConsumerWidget {
  const _UsageStatsBody({
    required this.stats,
    required this.allTime,
    required this.tabController,
  });

  final UsageStats stats;
  final bool allTime;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hasDataCap = ref.watch(dataCapInfoProvider).value?.enabled ?? false;
    final resetting = useState(false);
    final totals = allTime ? stats.lifetime : stats.thisMonth;
    final caption = allTime ? _sinceLabel(stats.since) : _monthLabel(stats);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 35.h,
          child: TabBar(
            controller: tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            splashBorderRadius: BorderRadius.circular(40),
            labelColor: context.actionTabbarSelectedText,
            dividerHeight: 0,
            unselectedLabelColor: context.actionTabbarDisabledText,
            labelStyle: textTheme.titleSmall,
            indicator: BoxDecoration(
              color: context.actionTabbarBg,
              borderRadius: BorderRadius.circular(40),
              shape: BoxShape.rectangle,
              border: Border.all(color: AppColors.blue3, width: 1),
            ),
            tabs: [
              Tab(
                key: const Key('usage_stats.this_month_tab'),
                child: Text('usage_stats_this_month'.i18n),
              ),
              Tab(
                key: const Key('usage_stats.all_time_tab'),
                child: Text('usage_stats_all_time'.i18n),
              ),
            ],
          ),
        ),
        const SizedBox(height: size24),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: defaultSize),
            child: Text(
              caption,
              key: const Key('usage_stats.caption'),
              style: textTheme.labelLarge!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 4.0),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            key: const Key('usage_stats.total'),
            icon: AppImagePaths.dataUsage,
            label: 'usage_stats_total'.i18n,
            trailing: _Bytes(totals.total),
          ),
        ),
        const SizedBox(height: defaultSize),
        AppCard(
          padding: EdgeInsets.zero,
          child: _PathTile(
            path: UsagePath.proxyless,
            bytes: totals[UsagePath.proxyless],
          ),
        ),
        const SizedBox(height: defaultSize),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, path) in const [
                UsagePath.lantern,
                UsagePath.personal,
                UsagePath.private,
                UsagePath.direct,
              ].indexed) ...[
                if (i > 0) DividerSpace(),
                _PathTile(
                  path: path,
                  bytes: totals[path],
                  // Only Lantern's servers count toward the cap.
                  note: hasDataCap && path == UsagePath.lantern
                      ? 'usage_stats_lantern_data_cap'.i18n
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: defaultSize),
        InfoRow(
          key: const Key('usage_stats.privacy'),
          backgroundColor: context.bgSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          text: 'usage_stats_privacy'.i18n,
        ),
        const SizedBox(height: defaultSize),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTextButton(
              key: const Key('usage_stats.reset'),
              label: 'usage_stats_reset'.i18n,
              onPressed: resetting.value
                  ? null
                  : () => _confirmReset(context, ref, resetting),
            ),
            if (resetting.value) ...[
              const SizedBox(width: 8),
              const SizedBox.square(
                key: Key('usage_stats.resetting'),
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: size24),
      ],
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    ValueNotifier<bool> resetting,
  ) async {
    var confirmed = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    await AppDialog.show(
      context: context,
      title: 'usage_stats_reset_title'.i18n,
      body: 'usage_stats_reset_body'.i18n,
      primaryLabel: 'usage_stats_reset_confirm'.i18n,
      dismissOnPrimary: false,
      onPrimaryPressed: () {
        confirmed = true;
        navigator.pop();
      },
      secondaryLabel: 'cancel'.i18n,
    );
    if (!confirmed || !context.mounted) return;
    resetting.value = true;
    final result = await ref.read(usageStatsProvider.notifier).reset();
    if (!context.mounted) return;
    resetting.value = false;
    result.match(
      (_) => context.showSnackBar('usage_stats_reset_failed'.i18n),
      (_) {},
    );
  }
}

class _PathTile extends StatelessWidget {
  const _PathTile({required this.path, required this.bytes, this.note});

  final UsagePath path;
  final UsageBytes bytes;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: context.textTertiary,
      letterSpacing: 0.0,
    );
    final (label, description) = switch (path) {
      UsagePath.proxyless => (
        'proxyless'.i18n,
        'usage_stats_proxyless_description'.i18n,
      ),
      UsagePath.lantern => (
        'lantern_servers'.i18n,
        'usage_stats_lantern_description'.i18n,
      ),
      UsagePath.personal => (
        'usage_stats_personal'.i18n,
        'usage_stats_personal_description'.i18n,
      ),
      UsagePath.private => (
        'private_servers'.i18n,
        'usage_stats_private_description'.i18n,
      ),
      UsagePath.direct => (
        'usage_stats_direct'.i18n,
        'usage_stats_direct_description'.i18n,
      ),
    };
    return AppTile(
      key: Key('usage_stats.path.${path.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      label: label,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: style),
          if (note != null)
            Text(
              note!,
              key: const Key('usage_stats.data_cap_note'),
              style: style.copyWith(color: context.textSecondary),
            ),
          Text(
            'usage_stats_up_down'.i18n.fill([
              bytes.up.siBytes,
              bytes.down.siBytes,
            ]),
            style: style,
          ),
        ],
      ),
      trailing: _Bytes(bytes.total),
    );
  }
}

class _Bytes extends StatelessWidget {
  const _Bytes(this.bytes);

  final int bytes;

  @override
  Widget build(BuildContext context) {
    return Text(
      bytes.siBytes,
      style: Theme.of(
        context,
      ).textTheme.titleMedium!.copyWith(color: context.textPrimary),
    );
  }
}

String _monthLabel(UsageStats stats) {
  final month = stats.monthStart;
  if (month == null) return '';
  return _format(month, (locale) => DateFormat.yMMMM(locale));
}

String _sinceLabel(DateTime? since) {
  if (since == null) return '';
  return 'usage_stats_since'.i18n.fill([
    _format(since, (locale) => DateFormat.yMMMd(locale)),
  ]);
}

String _format(DateTime date, DateFormat Function(String? locale) pattern) {
  try {
    return pattern(Localization.defaultLocale).format(date);
  } catch (_) {
    // No date symbols for this locale.
    return pattern('en_US').format(date);
  }
}
