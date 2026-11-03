import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';
import 'package:loader_overlay/loader_overlay.dart';

/// Opens the approval sheet on its own when a friend claims one of this
/// user's invites, over whatever screen shows: once per claim, in the
/// foreground, and never over a dialog, sheet or blocked flow ([routes]),
/// a checkout in progress, or the loading overlay: the same rules as
/// UserMessageHost. The claim arrives with the notifier's own poll; nothing
/// here calls the engine. A stealth build never prompts. [overlayVisible]
/// lets a test play the loading overlay.
void useHelperApprovalPrompt(
  BuildContext context,
  WidgetRef ref,
  UserMessageRouteObserver routes, {
  bool Function(BuildContext context)? overlayVisible,
  Duration retryInterval = const Duration(milliseconds: 250),
}) {
  final showing = useRef(false);
  final scheduled = useRef(false);

  useEffect(() {
    if (!HelpersNotifier.buildEnabled) return null;
    Timer? retry;
    late void Function() schedule;

    Future<void> prompt() async {
      if (!context.mounted || showing.value) return;
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      if (!routes.isReadyForMessages) return;
      if (ref.read(paymentSessionProvider)) return;
      final notifier = ref.read(helpersProvider.notifier);
      final invite = ref
          .read(helpersProvider)
          .view
          .invites
          .where((i) => i.claimed && !notifier.approvalPrompted(i.id))
          .firstOrNull;
      if (invite == null) return;
      // The overlay says nothing when it hides, so look again shortly, as
      // UserMessageHost does.
      if (overlayVisible?.call(context) ?? context.loaderOverlay.visible) {
        retry ??= Timer(retryInterval, () {
          retry = null;
          schedule();
        });
        return;
      }
      notifier.markApprovalPrompted(invite.id);
      showing.value = true;
      await showApproveHelperDialog(context, invite);
      showing.value = false;
    }

    // After the frame, so a screen that offers the codes itself (InviteShare)
    // has marked its invite first.
    schedule = () {
      if (scheduled.value) return;
      scheduled.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scheduled.value = false;
        unawaited(prompt());
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    };

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
    // A claim that came during checkout.
    final payment = ref.listenManual(paymentSessionProvider, (_, active) {
      if (!active) schedule();
    });
    // A claim that came while a dialog was open, or in the background.
    routes.changes.addListener(schedule);
    final lifecycle = AppLifecycleListener(onResume: schedule);
    return () {
      retry?.cancel();
      sub.close();
      payment.close();
      routes.changes.removeListener(schedule);
      lifecycle.dispose();
    };
  }, [routes]);
}
