import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// The inviter's helpers: who helps her, online or not, invites waiting on a
/// friend, and claims waiting on her.
@RoutePage(name: 'GetHelp')
class GetHelp extends HookConsumerWidget {
  const GetHelp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(helpersProvider);
    final view = state.view;
    final notifier = ref.read(helpersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    useEffect(() {
      // refreshIfUsed, not refresh: merely opening this screen must not touch
      // the keystore (Plan rules). The first invite unlocks it.
      unawaited(notifier.refreshIfUsed());
      // Online status changes while the screen is open.
      final timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => notifier.refreshIfUsed(),
      );
      return timer.cancel;
    }, const []);

    final claimed = view.invites.where((i) => i.claimed).toList();
    final pending = view.invites
        .where((i) => !i.claimed && !i.expired)
        .toList();

    return BaseScreen(
      title: 'helpers_title'.i18n,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: defaultSize),
        children: [
          if (state.keystoreReset) ...[
            AppCard(
              key: const Key('helpers.keystore_reset'),
              padding: const EdgeInsets.only(left: defaultSize),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      helperErrorText('keystore_reset'),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('helpers.keystore_reset.dismiss'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: notifier.acknowledgeKeystoreReset,
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultSize),
          ],
          Text(
            'helpers_intro'.i18n,
            style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: defaultSize),
          for (final inv in claimed) ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                tileKey: Key('helpers.claimed.${inv.id}'),
                label: 'invite_claimed_title'.i18n,
                subtitle: Text(
                  inv.volunteerName.isEmpty
                      ? 'helper_unnamed'.i18n
                      : inv.volunteerName,
                ),
                trailing: const Icon(Icons.chevron_right),
                onPressed: () => showApproveHelperSheet(context, inv),
              ),
            ),
            const SizedBox(height: defaultSize),
          ],
          if (view.helpers.isNotEmpty) ...[
            Text('helpers_list_title'.i18n, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, h) in view.helpers.indexed) ...[
                    if (i > 0) DividerSpace(),
                    _HelperRow(index: i, helper: h, notifier: notifier),
                  ],
                ],
              ),
            ),
            if (view.helpers.length == 1) ...[
              const SizedBox(height: defaultSize),
              Text(
                'helpers_nudge_second'.i18n,
                key: const Key('helpers.nudge'),
                style: textTheme.bodyMedium!.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: defaultSize),
          ] else if (claimed.isEmpty && pending.isEmpty) ...[
            Text('helpers_empty'.i18n, key: const Key('helpers.empty')),
            const SizedBox(height: defaultSize),
          ],
          for (final inv in pending)
            AppTile(
              label: 'invite_waiting'.i18n,
              subtitle: Text(
                'invite_expires'.i18n.fill([_hoursLeft(inv.expiresUnix)]),
              ),
              onPressed: () => appRouter.push(InviteShare(inviteId: inv.id)),
              trailing: IconButton(
                tooltip: 'invite_forget'.i18n,
                icon: const Icon(Icons.close),
                onPressed: () => notifier.forgetInvite(inv.id),
              ),
            ),
          const SizedBox(height: defaultSize),
          KeyedSubtree(
            key: const Key('helpers.invite'),
            child: PrimaryButton(
              label: 'invite_someone'.i18n,
              onPressed: () => _invite(context, ref, notifier),
            ),
          ),
          if (view.helpers.isNotEmpty || view.invites.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppTextButton(
              label: 'helpers_remove_all'.i18n,
              onPressed: () => _removeAll(context, notifier),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: defaultSize),
            Text(
              helperErrorText(state.error!),
              key: const Key('helpers.error'),
              style: textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    HelpersNotifier notifier,
  ) async {
    final name = await askHelperName(
      context,
      initial: ref.read(helpersProvider).view.myName,
      title: 'invite_someone'.i18n,
    );
    if (name == null || !context.mounted) return;
    final r = await notifier.createInvite(name);
    if (!context.mounted) return;
    final id = r.data['invite_id'];
    if (!r.ok || id is! String) {
      context.showSnackBarError(helperErrorText(r.error ?? 'unavailable'));
      return;
    }
    appRouter.push(InviteShare(inviteId: id));
  }

  // AppDialog runs onPrimaryPressed 400 ms after the dialog closes, when this
  // screen may be gone and its ref unusable. The notifier is keepAlive, so
  // the removal still happens.
  Future<void> _removeAll(BuildContext context, HelpersNotifier notifier) =>
      AppDialog.show(
        context: context,
        title: 'helpers_remove_all'.i18n,
        body: 'helpers_remove_all_body'.i18n,
        primaryLabel: 'remove'.i18n,
        onPrimaryPressed: notifier.endAllHelpers,
        secondaryLabel: 'cancel'.i18n,
      );
}

String _hoursLeft(int expiresUnix) {
  final left = expiresUnix - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return '${left <= 0 ? 0 : (left + 3599) ~/ 3600}';
}

class _HelperRow extends StatelessWidget {
  const _HelperRow({
    required this.index,
    required this.helper,
    required this.notifier,
  });

  final int index;
  final HelperPairingView helper;

  /// Held rather than read from a ref: see [GetHelp._removeAll].
  final HelpersNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final name = helper.name.isEmpty ? 'helper_unnamed'.i18n : helper.name;
    return AppTile(
      label: name,
      subtitle: Row(
        key: Key(
          helper.online ? 'helpers.online.$index' : 'helpers.offline.$index',
        ),
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: helper.online
                ? context.statusSuccessBgDot
                : context.textTertiary,
          ),
          const SizedBox(width: 6),
          Text(helper.online ? 'helper_online'.i18n : 'helper_offline'.i18n),
        ],
      ),
      trailing: IconButton(
        tooltip: 'remove'.i18n,
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => AppDialog.show(
          context: context,
          title: 'helper_remove_confirm_title'.i18n.fill([name]),
          body: 'helper_remove_confirm_body'.i18n.fill([name]),
          primaryLabel: 'remove'.i18n,
          onPrimaryPressed: () => notifier.endPairing(helper.pairingId),
          secondaryLabel: 'cancel'.i18n,
        ),
      ),
    );
  }
}
