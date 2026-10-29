import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// "Invite a Personal Proxy": asks the name the friend knows the user by,
/// creates the invite and opens it to share. The server-list menu, the VPN
/// tab banner and the Manage tab all start here. While a friend has claimed
/// an invite and waits on the user's approval, it opens that invite instead,
/// unless [resumeWaiting] is false (the Manage tab lists it already). An
/// invite no one has opened yet does not stop another.
Future<void> startPersonalProxyInvite(
  BuildContext context,
  WidgetRef ref, {
  bool resumeWaiting = true,
}) async {
  // Held rather than read after an await: the caller may be gone by then.
  final notifier = ref.read(helpersProvider.notifier);
  if (resumeWaiting) {
    // A device that used helper invites may not have loaded its view yet.
    if (!ref.read(helpersProvider).viewLoaded && notifier.used) {
      await notifier.refresh();
      if (!context.mounted) return;
    }
    final waiting = ref.read(helpersProvider).view.awaitingApproval;
    if (waiting != null) {
      appRouter.push(InviteShare(inviteId: waiting.id));
      return;
    }
  }
  final name = await askHelperName(
    context,
    initial: ref.read(helpersProvider).view.myName,
    title: 'invite_personal_proxy'.i18n,
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
