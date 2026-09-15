import 'package:flutter_earth_globe/globe_coordinates.dart';

/// Geo-resolved connection change emitted by ShareNotifier for the globe and
/// the arrival toast. Not the wire format.
class ActionModeConnectionEvent {
  /// 1 = connected, -1 = disconnected.
  final int state;

  /// Dart-side identity for matching connect/disconnect pairs; not the
  /// broflake worker index.
  final int workerIdx;

  /// Empty on -1 events, where only [workerIdx] matters.
  final String countryName;
  final String countryCode;
  final GlobeCoordinates? coordinates;

  /// True for events re-emitted to seed a globe that mounted mid-session, so
  /// the UI can skip the "new connection" burst.
  final bool isReplay;

  ActionModeConnectionEvent({
    required this.state,
    required this.workerIdx,
    this.countryName = '',
    this.countryCode = '',
    this.coordinates,
    this.isReplay = false,
  });
}
