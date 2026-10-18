import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/relay_stats.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/section_label.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';

void showAdvancedStatsSheet(BuildContext context) {
  showAppBottomSheet(
    context: context,
    title: 'advanced_stats'.i18n,
    builder: (context, scrollController) =>
        Expanded(child: AdvancedStatsView(scrollController: scrollController)),
  );
}

/// Data-relay figures for Unbounded volunteers. Byte counters only exist for
/// Unbounded, so SmC sessions get a note in place of live figures.
class AdvancedStatsView extends ConsumerWidget {
  const AdvancedStatsView({super.key, this.scrollController});
  final ScrollController? scrollController;

  static const topCountryCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shareProvider);
    final relay = state.relay;
    final smc = state.mode == ShareMode.smc;
    final live = !smc && relay.available;
    final countries = relay.topCountries(topCountryCount);
    final divider = Divider(height: 1, color: context.borderDefault);

    return ListView(
      key: const Key('advanced-stats.list'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (smc) ...[
          InfoRow(
            key: const Key('advanced-stats.smc-note'),
            text: 'advanced_stats_smc_note'.i18n,
          ),
          const SizedBox(height: 16),
        ],
        AppCard(
          child: Column(
            children: [
              if (!smc) ...[
                _StatRow(
                  label: 'advanced_stats_current_speed'.i18n,
                  value: live
                      ? _directions(
                          '${relay.speedDown.round().siBytes}/s',
                          '${relay.speedUp.round().siBytes}/s',
                        )
                      : '—',
                ),
                divider,
                _StatRow(
                  label: 'advanced_stats_session'.i18n,
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
                label: 'advanced_stats_all_time'.i18n,
                value: relay.lifetimeBytes.siBytes,
                detail: relay.lifetimeBytes > 0
                    ? _directions(
                        relay.lifetimeDown.siBytes,
                        relay.lifetimeUp.siBytes,
                      )
                    : null,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Text(
            'advanced_stats_direction_legend'.i18n,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
        ),
        const SizedBox(height: 16),
        SectionLabel('advanced_stats_countries'.i18n),
        const SizedBox(height: 4),
        AppCard(
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
      ],
    );
  }
}

String _directions(String down, String up) => '↓ $down  ↑ $up';

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.detail});
  final String label, value;
  final String? detail;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyLargeBold.copyWith(
                    color: context.textLink,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.stats});
  final RelayCountryStats stats;

  @override
  Widget build(BuildContext context) {
    final name = stats.isUnknown
        ? 'advanced_stats_unknown_country'.i18n
        : (stats.name.isEmpty ? stats.code : stats.name);
    final people = switch (stats.people) {
      0 => null,
      1 => 'advanced_stats_one_person'.i18n,
      _ => 'advanced_stats_people'.i18n.fill(['${stats.people}']),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 25,
              child: stats.isUnknown
                  ? Icon(Icons.public, size: 20, color: context.textTertiary)
                  : Flag(countryCode: stats.code),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.bodyLarge),
                  Text(
                    people == null
                        ? stats.bytes.siBytes
                        : '${stats.bytes.siBytes} · $people',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
