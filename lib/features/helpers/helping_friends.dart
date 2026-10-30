import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The Action Mode tab's "Your Personal Proxy connections" card, shown once
/// this device helps a friend. It opens [showHelpingFriendsSheet]. Its third
/// line, how many are connected right now, shows only once the engine
/// reports it.
class PersonalProxyConnectionsCard extends HookConsumerWidget {
  const PersonalProxyConnectionsCard({super.key});

  /// How often the card refreshes while it shows.
  @visibleForTesting
  static Duration refreshInterval = const Duration(seconds: 60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helping = ref.watch(helpersProvider.select((s) => s.view.helping));
    final tabVisible = ref.watch(actionModeTabVisibleProvider);
    final notifier = ref.read(helpersProvider.notifier);

    // Today's totals move, and the inviter can end a pairing, without
    // anything pending to poll for. Refresh while this shows and the app and
    // this tab are in front; each refresh reaches lantern-cloud.
    useEffect(() {
      if (!tabVisible) return null;
      final timer = Timer.periodic(refreshInterval, (_) {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        unawaited(notifier.refreshIfUsed());
      });
      return timer.cancel;
    }, [tabVisible]);

    return AppCard(
      padding: EdgeInsets.zero,
      child: SettingTile(
        tileKey: const Key('action_mode.personal_proxy_connections'),
        label: 'helping_connections_title'.i18n,
        value: helpingFriendsCount(helping.length),
        subtitle: connectedRightNow(helping),
        subtitleColor: context.textTertiary,
        icon: AppImagePaths.personAdd,
        actions: const [AppImage(path: AppImagePaths.arrowForward)],
        onTap: () => showHelpingFriendsSheet(context),
      ),
    );
  }
}

/// "1 friend", "3 friends".
String helpingFriendsCount(int n) => n == 1
    ? 'helping_friends_one'.i18n
    : 'helping_friends_count'.i18n.fill([n]);

/// "Sara connected right now" or "2 connected right now", or null while any
/// friend's live status is unknown: no status rather than a wrong one.
String? connectedRightNow(List<HelperPairingView> helping) {
  if (helping.isEmpty || helping.any((p) => p.connected == null)) return null;
  final connected = helping.where((p) => p.connected == true).toList();
  if (connected.length == 1) {
    return 'helping_connected_named'.i18n.fill([_name(connected.single)]);
  }
  return 'helping_connected_count'.i18n.fill([connected.length]);
}

/// The friends this device helps, in the app's bottom sheet: each with since
/// when, Connected or Not connected once known, and remove; "Paste another
/// invite link"; today's data relayed; and "Help others too".
void showHelpingFriendsSheet(BuildContext context) {
  showAppBottomSheet(
    context: context,
    title: 'helping_sheet_title'.i18n,
    subtitle: Consumer(
      builder: (context, ref, _) {
        final line = connectedRightNow(
          ref.watch(helpersProvider.select((s) => s.view.helping)),
        );
        if (line == null) return const SizedBox.shrink();
        return Text(
          line,
          key: const Key('helping.sheet.connected'),
          style: Theme.of(
            context,
          ).textTheme.labelMedium!.copyWith(color: context.textTertiary),
        );
      },
    ),
    builder: (sheetContext, scrollController) => Flexible(
      child: HelpingFriendsSheet(scrollController: scrollController),
    ),
  );
}

class HelpingFriendsSheet extends HookConsumerWidget {
  const HelpingFriendsSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpers = ref.watch(helpersProvider);
    final sharing = ref.watch(
      shareProvider.select((s) => s.active || s.probing),
    );
    final notifier = ref.read(helpersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    useEffect(() {
      unawaited(notifier.loadHelpOthers());
      return null;
    }, const []);

    final helping = helpers.view.helping;
    final activity = helpers.view.activity;
    final connectedColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.green3
        : AppColors.green6;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(defaultSize),
      children: [
        if (!sharing) ...[
          Text(
            'helping_sharing_off_warning'.i18n,
            key: const Key('helping.sharing_off'),
            style: textTheme.bodyMedium!.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: defaultSize),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: HeaderText('helping_your_friends'.i18n),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final p in helping) ...[
                AppTile(
                  tileKey: Key('helping.friend.${p.pairingId}'),
                  icon: AppImagePaths.person,
                  label: _name(p),
                  subtitle: p.sinceUnix > 0
                      ? Text(
                          helperSinceLabel(p.sinceUnix),
                          style: textTheme.labelMedium!.copyWith(
                            color: context.textTertiary,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.connected != null)
                        Text(
                          p.connected!
                              ? 'helping_connected'.i18n
                              : 'helping_not_connected'.i18n,
                          key: Key('helping.status.${p.pairingId}'),
                          style: textTheme.labelLarge!.copyWith(
                            color: p.connected!
                                ? connectedColor
                                : context.textSecondary,
                          ),
                        ),
                      IconButton(
                        key: Key('helping.remove.${p.pairingId}'),
                        tooltip: 'helping_remove'.i18n,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmStop(context, notifier, p),
                      ),
                    ],
                  ),
                ),
                const DividerSpace(),
              ],
              AppTile(
                tileKey: const Key('helping.paste_another'),
                icon: AppImagePaths.plus,
                label: 'helping_paste_another'.i18n,
                trailing: const AppImage(path: AppImagePaths.arrowForward),
                onPressed: () {
                  Navigator.of(context).pop();
                  appRouter.push(HelpFriend());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: defaultSize),
        AppCard(
          padding: EdgeInsets.zero,
          child: SettingTile(
            tileKey: const Key('helping.data_relayed'),
            label: 'helping_data_relayed'.i18n,
            value: (activity?.relayedBytes ?? 0).siBytes,
            subtitle: 'helping_active_today'.i18n.fill([
              helpingDuration(activity?.activeSeconds ?? 0),
            ]),
            subtitleColor: context.textTertiary,
            icon: AppImagePaths.dataUsage,
            actions: const [],
          ),
        ),
        const SizedBox(height: defaultSize),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              // Changing it rebuilds the sharing session, so the people
              // helped reconnect after a few seconds.
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
      ],
    );
  }

  // AppDialog runs onPrimaryPressed 400 ms after the dialog closes, when
  // this sheet may be gone and its ref unusable. The notifier is keepAlive,
  // so it is held instead and the stop still happens.
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

/// "Since Oct 20", localized, for a pairing made at [unix].
String helperSinceLabel(int unix) => 'helping_since'.i18n.fill([
  DateFormat.MMMd().format(DateTime.fromMillisecondsSinceEpoch(unix * 1000)),
]);
