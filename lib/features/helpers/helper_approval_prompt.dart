import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

/// Opens the approval sheet on its own when a friend claims one of this
/// user's invites, over whatever screen shows: once per claim, in the
/// foreground, and never over a dialog, sheet or blocked flow ([routes]).
/// The claim arrives with the notifier's own poll; nothing here calls the
/// engine. A stealth build never prompts.
void useHelperApprovalPrompt(
  BuildContext context,
  WidgetRef ref,
  UserMessageRouteObserver routes,
) {
  final showing = useRef(false);
  final scheduled = useRef(false);

  useEffect(() {
    if (!HelpersNotifier.buildEnabled) return null;

    Future<void> prompt() async {
      if (!context.mounted || showing.value) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      if (!routes.isReadyForMessages) return;
      final notifier = ref.read(helpersProvider.notifier);
      final invite = ref
          .read(helpersProvider)
          .view
          .invites
          .where((i) => i.claimed && !notifier.approvalPrompted(i.id))
          .firstOrNull;
      if (invite == null) return;
      notifier.markApprovalPrompted(invite.id);
      showing.value = true;
      await showApproveHelperSheet(context, invite);
      showing.value = false;
    }

    // After the frame, so a screen that offers the codes itself (InviteShare)
    // has marked its invite first.
    void schedule() {
      if (scheduled.value) return;
      scheduled.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scheduled.value = false;
        unawaited(prompt());
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    final sub = ref.listenManual(
      helpersProvider.select(
        (s) => [
          for (final i in s.view.invites)
            if (i.claimed) i.id,
        ].join(','),
      ),
      (_, _) => schedule(),
      fireImmediately: true,
    );
    // A claim that came while a dialog was open, or in the background.
    routes.changes.addListener(schedule);
    final lifecycle = AppLifecycleListener(onResume: schedule);
    return () {
      sub.close();
      routes.changes.removeListener(schedule);
      lifecycle.dispose();
    };
  }, [routes]);
}
