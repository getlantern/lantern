import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

/// "Invite a Personal Proxy": opens the invite screen, which asks the name
/// the friend knows the user by and makes the invite. The server-list menu,
/// the VPN tab banner and the Manage tab all start here. While a friend has
/// claimed an invite and waits on the user's approval, it opens that
/// approval instead, unless [resumeWaiting] is false (the Manage tab lists
/// it already). An invite no one has opened yet does not stop another.
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
      final r = await notifier.refresh();
      if (!context.mounted) return;
      // Without the view a claimed invite waiting on approval is unknown;
      // creating another would leave that friend waiting.
      if (!r.ok) {
        context.showSnackBarError(helperErrorText(r.error ?? 'unavailable'));
        return;
      }
    }
    final waiting = ref.read(helpersProvider).view.awaitingApproval;
    if (waiting != null) {
      // The app-wide prompt need not offer it as well.
      notifier.markApprovalPrompted(waiting.id);
      await showApproveHelperDialog(context, ref, waiting);
      return;
    }
  }
  appRouter.push(InviteShare());
}
