import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/usage_stats.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';
import 'package:lantern/features/setting/provider/usage_stats_notifier.dart';

/// How often the screen reloads the stats while it's on top and the app is
/// in the foreground.
const usageStatsRefreshInterval = Duration(seconds: 10);

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

    useEffect(() {
      final timer = Timer.periodic(usageStatsRefreshInterval, (_) {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
        unawaited(ref.read(usageStatsProvider.notifier).refresh());
      });
      return timer.cancel;
    }, const []);

    return BaseScreen(
      title: 'usage_stats'.i18n,
      body: statsAsync.when(
        skipLoadingOnRefresh: true,
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

class _UsageStatsBody extends ConsumerWidget {
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
            note: hasDataCap ? 'usage_stats_proxyless_data_cap'.i18n : null,
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
                _PathTile(path: path, bytes: totals[path]),
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
        Center(
          child: AppTextButton(
            key: const Key('usage_stats.reset'),
            label: 'usage_stats_reset'.i18n,
            onPressed: () => _confirmReset(context, ref),
          ),
        ),
        const SizedBox(height: size24),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
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
    final result = await ref.read(usageStatsProvider.notifier).reset();
    if (!context.mounted) return;
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
