import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';

import '../../core/common/common.dart';

/// Probe latency below this shows a green dot; at or above it, yellow.
const fastLatencyThresholdMs = 100;

/// What a server list row shows for one server, or for the best of a group.
sealed class LatencyStatus {
  const LatencyStatus();

  factory LatencyStatus.of(Server server) {
    if (server.isProbedUnreachable) return const LatencyUnreachable();
    if (server.hasSuccessfulProbe) {
      return LatencyMeasured(server.selectionHistory!.lastSuccessDelayMs);
    }
    return const LatencyTesting();
  }

  /// The fastest measured server wins; failing that, a group still being
  /// tested reads as testing, and only an all-unreachable group reads as
  /// unreachable.
  factory LatencyStatus.best(Iterable<Server> servers) {
    LatencyStatus best = const LatencyUnreachable();
    for (final status in servers.map(LatencyStatus.of)) {
      best = switch ((best, status)) {
        (LatencyMeasured(:final ms), LatencyMeasured(ms: final other)) =>
          other < ms ? status : best,
        (LatencyMeasured(), _) => best,
        (_, LatencyMeasured()) => status,
        (LatencyUnreachable(), LatencyTesting()) => status,
        _ => best,
      };
    }
    return best;
  }
}

class LatencyMeasured extends LatencyStatus {
  final int ms;

  const LatencyMeasured(this.ms);

  bool get isFast => ms < fastLatencyThresholdMs;
}

class LatencyTesting extends LatencyStatus {
  const LatencyTesting();
}

class LatencyUnreachable extends LatencyStatus {
  const LatencyUnreachable();
}

/// A status dot plus the probe round trip ("42 ms"), "Testing…", or
/// "Unreachable", for the trailing edge of a server list row.
class LatencyIndicator extends StatelessWidget {
  final LatencyStatus status;

  const LatencyIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (dotColor, label, textColor) = switch (status) {
      LatencyMeasured(:final ms, :final isFast) => (
        isFast ? context.statusSuccessBgDot : context.statusWarningBgDot,
        '$ms ms',
        context.textSecondary,
      ),
      LatencyTesting() => (
        context.statusNeutralBgDot,
        'latency_testing'.i18n,
        context.textSecondary,
      ),
      LatencyUnreachable() => (
        context.statusErrorBgDot,
        'latency_unreachable'.i18n,
        context.statusErrorText,
      ),
    };
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: textColor,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget labelWidget = Text(label, style: style);
    if (status is LatencyMeasured) {
      // Urbanist has no tabular figures (the fontFeatures request above is
      // inert) and latencies vary from 2 to 4 digits, so a bare label would
      // put each row's dot in a different column. An invisible widest-case
      // template fixes the label block's width in the current style and
      // scale; the Stack still grows if a real label ever exceeds it.
      labelWidget = Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text('8888 ms', style: style),
          ),
          labelWidget,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        SizedBox.square(
          dimension: 16,
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        labelWidget,
      ],
    );
  }
}
