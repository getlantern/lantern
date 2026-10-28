import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/relay_stats.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';

const _cardPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

/// The user-facing name of a sharing mode, or null when not sharing.
String? shareModeLabel(ShareMode mode) => switch (mode) {
  ShareMode.smc => 'share_mode_smc'.i18n,
  ShareMode.unbounded => 'share_mode_unbounded'.i18n,
  ShareMode.off => null,
};

void showAdvancedStatsSheet(BuildContext context) {
  showAppBottomSheet(
    context: context,
    title: 'people_helped_title'.i18n,
    scrollControlDisabledMaxHeightRatio: 0.8,
    subtitle: Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(shareProvider);
        final format = NumberFormat.decimalPattern();
        return Text(
          'people_helped_subtitle'.i18n.fill([
            format.format(state.totalCount),
            format.format(state.activeCount),
          ]),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
        );
      },
    ),
    builder: (context, scrollController) =>
        Expanded(child: AdvancedStatsView(scrollController: scrollController)),
  );
}

/// Countries helped and data-relay figures for volunteers, in either
/// sharing mode.
class AdvancedStatsView extends ConsumerWidget {
  const AdvancedStatsView({super.key, this.scrollController});

  final ScrollController? scrollController;

  static const topCountryCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final relay = state.relay;
    final live = relay.available;
    final countries = relay.topCountries(topCountryCount);
    // A first session's figures equal the all-time ones, so the row would
    // only repeat them. Installs that predate the session counter still show
    // it once earlier sessions have relayed something.
    final showSession =
        ref.watch(appSettingProvider.select((s) => s.unboundedSessionCount)) >
            1 ||
        relay.lifetimeBytes > relay.sessionBytes;
    final divider = Divider(height: 1, color: context.borderDefault);

    return ListView(
      key: const Key('advanced-stats.list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _SectionTitle('advanced_stats_by_country'.i18n),
        AppCard(
          bgColor: context.bgSurface,
          padding: _cardPadding,
          child: countries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'advanced_stats_no_countries'.i18n,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < countries.length; i++) ...[
                      if (i > 0) divider,
                      _CountryRow(stats: countries[i]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionTitle('advanced_stats_data_relayed'.i18n),
        AppCard(
          padding: _cardPadding,
          bgColor: context.bgSurface,
          child: Column(
            children: [
              if (showSession) ...[
                _StatRow(
                  key: const Key('advanced-stats.session'),
                  label: 'advanced_stats_this_session'.i18n,
                  value: live ? relay.sessionBytes.siBytes : '—',
                  detail: live
                      ? _directions(
                          relay.sessionDown.siBytes,
                          relay.sessionUp.siBytes,
                        )
                      : null,
                ),
                divider,
              ],
              _StatRow(
                label: 'advanced_stats_all_time_short'.i18n,
                value: relay.lifetimeBytes.siBytes,
                detail: relay.lifetimeBytes > 0
                    ? _directions(
                        relay.lifetimeDown.siBytes,
                        relay.lifetimeUp.siBytes,
                      )
                    : null,
              ),
              divider,
              _StatRow(
                label: 'advanced_stats_current_speed'.i18n,
                // Sent is what this device uploads to the people it helps.
                value: live
                    ? 'advanced_stats_speed'.i18n.fill([
                        '${relay.speedDown.round().siBytes}/s',
                        '${relay.speedUp.round().siBytes}/s',
                      ])
                    : '—',
              ),
              divider,
              _StatRow(
                key: const Key('advanced-stats.mode'),
                label: 'advanced_stats_mode'.i18n,
                value: shareModeLabel(state.mode) ?? 'smc_status_off'.i18n,
                detail:
                    state.mode == ShareMode.unbounded &&
                        state.fallbackReason != null
                    ? 'advanced_stats_mode_fallback'.i18n.fill([
                        state.fallbackReason!,
                      ])
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section heading in the row text style, per the Figma.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
  );
}

String _directions(String down, String up) =>
    'advanced_stats_directions'.i18n.fill([down, up]);

/// Label with an optional detail line, and a value in the right column.
class _StatRow extends StatelessWidget {
  const _StatRow({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });

  final String label, value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.bodyLarge),
                if (detail != null)
                  Text(
                    detail!,
                    style: textTheme.labelMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyLarge!.copyWith(color: context.textLink),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.stats});

  final RelayCountryStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = stats.isUnknown
        ? 'advanced_stats_unknown_country'.i18n
        : (stats.name.isEmpty ? stats.code : stats.name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                SizedBox(
                  width: 25,
                  child: stats.isUnknown
                      ? Icon(
                          Icons.public,
                          size: 20,
                          color: context.textTertiary,
                        )
                      : Flag(countryCode: stats.code),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: textTheme.bodyLarge),
                      // Direct sharing reports people without bytes, so a
                      // row can have nothing to say here.
                      if (stats.bytes > 0)
                        Text(
                          'advanced_stats_relayed'.i18n.fill([
                            stats.bytes.siBytes,
                          ]),
                          style: textTheme.labelMedium?.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (stats.people > 0)
            Flexible(
              child: Text(
                peopleCountLabel(stats.people),
                textAlign: TextAlign.end,
                style: textTheme.bodyLarge!.copyWith(color: context.textLink),
              ),
            ),
        ],
      ),
    );
  }
}
