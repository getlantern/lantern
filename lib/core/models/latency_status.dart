import 'package:lantern/core/models/available_servers.dart';

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
