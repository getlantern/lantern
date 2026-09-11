import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/models/action_mode_connection_event.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lottie/lottie.dart';

/// Pill under the globe. Shows "Helping a new person in the country" with a
/// heart burst for a few seconds after each arrival, otherwise "Waiting for
/// connections..." while Unbounded is on with no peers.
class PeerStatusPill extends HookConsumerWidget {
  const PeerStatusPill({super.key});

  static const _showFor = Duration(milliseconds: 3500);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrival = useState<ActionModeConnectionEvent?>(null);

    useEffect(() {
      Timer? timer;
      final sub = ref.read(shareProvider.notifier).connectionEvents.listen((
        event,
      ) {
        if (event.state != 1 || event.isReplay || event.countryName.isEmpty) {
          return;
        }
        arrival.value = event;
        timer?.cancel();
        timer = Timer(_showFor, () => arrival.value = null);
      });
      return () {
        sub.cancel();
        timer?.cancel();
      };
    }, const []);

    final share = ref.watch(shareProvider);
    // Keyed off the live peer count: an expired arrival does not mean nobody
    // is connected.
    final waiting =
        share.mode == ShareMode.unbounded &&
        share.active &&
        share.activeCount == 0;

    final Widget child;
    if (arrival.value case final event?) {
      // Keyed per arrival so a new one restarts the heart burst.
      child = _Pill(
        key: ValueKey('arrival-${event.workerIdx}'),
        text: 'smc_arrival_toast'.i18n.fill([event.countryName]),
        heart: true,
      );
    } else if (waiting) {
      child = _Pill(
        key: const ValueKey('arrival-waiting'),
        text: 'unbounded_waiting_for_connections'.i18n,
        heart: false,
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('arrival-idle'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text, required this.heart});

  final String text;
  final bool heart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Container(
        padding: heart
            ? const EdgeInsets.fromLTRB(10, 8, 16, 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        // Lets the heart burst overflow the pill and spray over the globe.
        clipBehavior: Clip.none,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
          boxShadow: heart
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (heart) ...[
              // Slot and burst offsets mirror unbounded.lantern.io's CSS;
              // 420x502 is explosion.json's native canvas.
              SizedBox(
                width: 22,
                height: 19,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: -55,
                      left: -105,
                      width: 420,
                      height: 502,
                      child: Lottie.asset(
                        'assets/unbounded/explosion.json',
                        repeat: false,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const CustomPaint(painter: _HeartPainter()),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: heart ? null : theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart from getlantern/unbounded (viewBox 0 0 32 27, fill #FF5A79).
class _HeartPainter extends CustomPainter {
  const _HeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFF5A79);
    final path = Path()
      ..moveTo(31.5035, 5.87209)
      ..cubicTo(28.0938, -3.18494, 17.0123, 0.864084, 16, 5.3926)
      ..cubicTo(14.6148, 0.597701, 3.79965, -2.97183, 0.496497, 5.87209)
      ..cubicTo(-3.17959, 15.7283, 14.7214, 24.5722, 16, 26.0107)
      ..cubicTo(17.2786, 24.8386, 35.1796, 15.5684, 31.5035, 5.87209)
      ..close();
    final scaled = path.transform(
      Matrix4.diagonal3Values(
        size.width / 32.0,
        size.height / 27.0,
        1.0,
      ).storage,
    );
    canvas.drawPath(scaled, paint);
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) => false;
}
