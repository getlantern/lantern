import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_section.dart'
    show HelperKeystoreResetNotice;
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/personal_proxy_invite.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// Manage Private Locations' "Personal Proxies": each friend with Rename and
/// Remove, invites waiting on a friend (Cancel) or on the user (compare
/// codes), Invite another, and remove all.
class PersonalProxiesTab extends HookConsumerWidget {
  const PersonalProxiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(helpersProvider);
    final view = state.view;
    final notifier = ref.read(helpersProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    // TabBarView builds this only while it is the tab shown, so the timer
    // runs only then, and skips its refresh while the app is not in front.
    useEffect(() {
      // refreshIfUsed, not refresh: showing this tab must not touch the
      // keystore. The first invite unlocks it.
      unawaited(notifier.refreshIfUsed());
      // Online status changes while the tab is shown.
      final timer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        unawaited(notifier.refreshIfUsed());
      });
      return timer.cancel;
    }, const []);

    final claimed = view.invites.where((i) => i.claimed).toList();
    final pending = view.invites
        .where((i) => !i.claimed && !i.expired)
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: defaultSize),
      children: [
        if (state.keystoreReset) ...[
          HelperKeystoreResetNotice(notifier: notifier),
          const SizedBox(height: defaultSize),
        ],
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
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, h) in view.helpers.indexed) ...[
                  if (i > 0) DividerSpace(),
                  _ProxyRow(index: i, helper: h, notifier: notifier),
                ],
              ],
            ),
          ),
          const SizedBox(height: defaultSize),
        ],
        for (final inv in pending)
          AppTile(
            label: 'invite_waiting'.i18n,
            subtitle: Text(
              'invite_expires'.i18n.fill([_hoursLeft(inv.expiresUnix)]),
            ),
            onPressed: () => appRouter.push(InviteShare(inviteId: inv.id)),
            trailing: AppTextButton(
              key: Key('personal_proxies.cancel.${inv.id}'),
              label: 'cancel'.i18n,
              onPressed: () => notifier.forgetInvite(inv.id),
            ),
          ),
        const SizedBox(height: defaultSize),
        KeyedSubtree(
          key: const Key('personal_proxies.invite'),
          child: PrimaryButton(
            label: 'invite_another'.i18n,
            onPressed: () =>
                startPersonalProxyInvite(context, ref, resumeWaiting: false),
          ),
        ),
        if (view.helpers.isNotEmpty || view.invites.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppTextButton(
            key: const Key('personal_proxies.remove_all'),
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
    );
  }

  // AppDialog runs onPrimaryPressed 400 ms after the dialog closes, when this
  // tab may be gone and its ref unusable. The notifier is keepAlive, so the
  // removal still happens.
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

class _ProxyRow extends StatelessWidget {
  const _ProxyRow({
    required this.index,
    required this.helper,
    required this.notifier,
  });

  final int index;
  final HelperPairingView helper;

  /// Held rather than read from a ref: see [PersonalProxiesTab._removeAll].
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextButton(
            key: Key('personal_proxies.rename.${helper.pairingId}'),
            label: 'rename'.i18n,
            onPressed: () => _rename(context),
          ),
          AppTextButton(
            key: Key('personal_proxies.remove.${helper.pairingId}'),
            label: 'remove'.i18n,
            onPressed: () => AppDialog.show(
              context: context,
              title: 'helper_remove_confirm_title'.i18n.fill([name]),
              body: 'helper_remove_confirm_body'.i18n.fill([name]),
              primaryLabel: 'remove'.i18n,
              onPrimaryPressed: () => notifier.endPairing(helper.pairingId),
              secondaryLabel: 'cancel'.i18n,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await askHelperName(
      context,
      initial: helper.name,
      title: 'rename'.i18n,
      label: 'personal_proxy_nickname_label'.i18n,
      // A blank nickname restores the friend's own name.
      allowEmpty: true,
    );
    if (name == null) return;
    final r = await notifier.renameHelper(helper.pairingId, name);
    if (!r.ok && context.mounted) {
      context.showSnackBarError(helperErrorText(r.error ?? 'unavailable'));
    }
  }
}
