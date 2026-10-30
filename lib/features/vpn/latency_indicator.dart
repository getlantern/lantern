import 'package:flutter/material.dart';
import 'package:lantern/core/models/latency_status.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';

import '../../core/common/common.dart';

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
    final style = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(color: textColor);

    Widget labelWidget = Text(label, style: style);
    if (status is LatencyMeasured) {
      // The app font has no tabular figures and latencies run 2 to 4 digits,
      // so give every label the widest one's width to keep the dots in a column.
      final widest = TextPainter(
        text: TextSpan(text: '8888 ms', style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      labelWidget = SizedBox(
        width: widest.width,
        child: Text(label, style: style, textAlign: TextAlign.end),
      );
      widest.dispose();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        labelWidget,
      ],
    );
  }
}

/// A server row's trailing edge: the latency readout, then the chevron slot.
/// Rows without a chevron keep the slot as a [ChevronPlaceholder] so their
/// latency labels line up with the country rows that have one.
class LatencyTrailing extends StatelessWidget {
  final LatencyStatus status;
  final Widget chevron;

  const LatencyTrailing({
    super.key,
    required this.status,
    this.chevron = const ChevronPlaceholder(),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        LatencyIndicator(status: status),
        chevron,
      ],
    );
  }
}
