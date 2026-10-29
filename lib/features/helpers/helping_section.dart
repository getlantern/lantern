import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// "You're helping": one row per person this device helps, by the name their
/// app sent, with today's totals and "Help others too". It shows no live
/// status for the people helped: that would expose their activity to anyone
/// holding this device. Today's totals cover all sharing, paired and pool
/// together, until per-person attribution exists (open question 1).
class HelpingSection extends HookConsumerWidget {
  const HelpingSection({super.key});

  /// How often the section refreshes while it shows someone helped.
  @visibleForTesting
  static Duration refreshInterval = const Duration(seconds: 60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpers = ref.watch(helpersProvider);
    final sharing = ref.watch(
      shareProvider.select((s) => s.active || s.probing),
    );
    final tabVisible = ref.watch(actionModeTabVisibleProvider);
    final notifier = ref.read(helpersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    useEffect(() {
      unawaited(notifier.loadHelpOthers());
      return null;
    }, const []);

    final helping = helpers.view.helping;
    final helpsSomeone = helping.isNotEmpty;

    // Today's totals move, and the inviter can end a pairing, without
    // anything pending to poll for. Refresh while this shows someone helped
    // and the app and this tab are in front; each refresh reaches
    // lantern-cloud.
    useEffect(() {
      if (!helpsSomeone || !tabVisible) return null;
      final timer = Timer.periodic(refreshInterval, (_) {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        unawaited(notifier.refreshIfUsed());
      });
      return timer.cancel;
    }, [helpsSomeone, tabVisible]);

    // A volunteer who never opens the Personal Proxies tab must still learn
    // that the keystore lost the old names.
    final notice = helpers.keystoreReset
        ? Padding(
            padding: const EdgeInsets.only(top: defaultSize),
            child: HelperKeystoreResetNotice(notifier: notifier),
          )
        : null;
    if (!helpsSomeone) return notice ?? const SizedBox.shrink();
    final activity = helpers.view.activity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?notice,
        Padding(
          padding: const EdgeInsets.only(top: defaultSize),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'helping_title'.i18n,
                    style: textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'helping_today'.i18n.fill([
                      helpingDuration(activity?.activeSeconds ?? 0),
                      (activity?.relayedBytes ?? 0).siBytes,
                    ]),
                    key: const Key('helping.today'),
                    style: textTheme.labelMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ),
                if (!sharing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'helping_sharing_off_warning'.i18n,
                      key: const Key('helping.sharing_off'),
                      style: textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final p in helping)
                  AppTile(
                    label: _name(p),
                    subtitle: p.sinceUnix > 0
                        ? Text('helping_since'.i18n.fill([_date(p.sinceUnix)]))
                        : null,
                    trailing: IconButton(
                      key: Key('helping.remove.${p.pairingId}'),
                      tooltip: 'helping_remove'.i18n,
                      icon: const Icon(Icons.close),
                      onPressed: () => _confirmStop(context, notifier, p),
                    ),
                  ),
                DividerSpace(),
                AppTile(
                  label: 'help_others_too'.i18n,
                  subtitle: Text(
                    'help_others_too_body'.i18n,
                    style: textTheme.labelMedium?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  trailing: Switch(
                    key: const Key('helping.help_others_switch'),
                    value: helpers.helpOthers,
                    onChanged: notifier.setHelpOthers,
                  ),
                  onPressed: () => notifier.setHelpOthers(!helpers.helpOthers),
                ),
                // Changing it rebuilds the sharing session (Task 7), so the
                // people helped reconnect after a few seconds.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'help_others_too_note'.i18n,
                    style: textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // AppDialog runs onPrimaryPressed 400 ms after the dialog closes, when
  // this section may be gone and its ref unusable. The notifier is
  // keepAlive, so it is held instead and the stop still happens.
  Future<void> _confirmStop(
    BuildContext context,
    HelpersNotifier notifier,
    HelperPairingView p,
  ) {
    final pairingId = p.pairingId;
    return AppDialog.show(
      context: context,
      title: 'helping_remove'.i18n,
      body: 'helping_remove_confirm'.i18n.fill([_name(p)]),
      primaryLabel: 'helping_remove'.i18n,
      onPrimaryPressed: () => notifier.endPairing(pairingId),
      secondaryLabel: 'cancel'.i18n,
    );
  }
}

/// Says the keystore lost the old key, so the names of the people helped
/// could not be read, until the user dismisses it.
class HelperKeystoreResetNotice extends StatelessWidget {
  const HelperKeystoreResetNotice({super.key, required this.notifier});

  final HelpersNotifier notifier;

  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('helping.keystore_reset'),
    padding: const EdgeInsets.only(left: defaultSize),
    child: Row(
      children: [
        Expanded(
          child: Text(
            helperErrorText('keystore_reset'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton(
          key: const Key('helping.keystore_reset.dismiss'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: notifier.acknowledgeKeystoreReset,
        ),
      ],
    ),
  );
}

String _name(HelperPairingView p) =>
    p.name.isEmpty ? 'helping_unnamed'.i18n : p.name;

/// Whole hours and the minutes left over.
(int, int) helpingHoursMinutes(int seconds) =>
    (seconds ~/ 3600, (seconds % 3600) ~/ 60);

/// "3h 20m" or "45m", localized.
String helpingDuration(int seconds) {
  final (h, m) = helpingHoursMinutes(seconds);
  return h > 0
      ? 'helping_duration_hm'.i18n.fill([h, m])
      : 'helping_duration_m'.i18n.fill([m]);
}

String _date(int unix) =>
    DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));
