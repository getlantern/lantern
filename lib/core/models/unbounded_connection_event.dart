import 'package:flutter_earth_globe/globe_coordinates.dart';

/// Internal Dart-side connection-change model the ShareNotifier emits
/// to the globe via _eventController. NOT the wire format —
/// FlutterEvent messages from lantern-core (forwarded from radiance)
/// are parsed inline in share_my_connection.dart's event subscription
/// as `{state, source, timestamp}` and synthesized into this model
/// after geo-resolution.
///
/// workerIdx here is the Dart-side identity counter (_workerSeq++ in
/// the notifier), not the broflake worker index — it's a stable
/// handle for matching accept/close pairs and cancelling pending arc
/// removals when a peer reconnects from the same IP.
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
}

/// Tracks live and cumulative connection counts for Unbounded.
class UnboundedStats {
  final int activeCount;
  final int totalCount;

  const UnboundedStats({this.activeCount = 0, this.totalCount = 0});
}
