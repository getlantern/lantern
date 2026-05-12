import 'package:flutter_earth_globe/globe_coordinates.dart';

/// Represents a consumer connection change from the broflake widget proxy.
class UnboundedConnectionEvent {
  final int state; // 1 = connected, -1 = disconnected
  final int workerIdx;
  final String addr; // IP address
  // Geo fields are populated by ShareNotifier after peer lookup. Empty on
  // legacy events and on -1 frames (where only workerIdx matters for the
  // globe to remove the arc).
  final String countryName;
  final String countryCode;
  final String flagEmoji;
  final GlobeCoordinates? coordinates;
  // True for synthetic events the notifier emits to seed a newly-mounted
  // globe with peers that connected before the screen opened. Lets the UI
  // suppress the "new connection from <country>" burst for replays.
  final bool isReplay;

  UnboundedConnectionEvent({
    required this.state,
    required this.workerIdx,
    required this.addr,
    this.countryName = '',
    this.countryCode = '',
    this.flagEmoji = '',
    this.coordinates,
    this.isReplay = false,
  });

  factory UnboundedConnectionEvent.fromJson(Map<String, dynamic> json) {
    return UnboundedConnectionEvent(
      state: json['state'] as int,
      workerIdx: json['workerIdx'] as int,
      addr: json['addr'] as String? ?? '',
    );
  }
}

/// Tracks live and cumulative connection counts for Unbounded.
class UnboundedStats {
  final int activeCount;
  final int totalCount;

  const UnboundedStats({this.activeCount = 0, this.totalCount = 0});
}
