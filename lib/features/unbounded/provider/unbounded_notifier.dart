import 'dart:async';

import 'package:lantern/core/models/unbounded_connection_event.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unbounded_notifier.g.dart';

@Riverpod(keepAlive: true)
class UnboundedNotifier extends _$UnboundedNotifier {
  final _eventController =
      StreamController<UnboundedConnectionEvent>.broadcast();

  /// Individual connection events for the globe view to animate arcs.
  Stream<UnboundedConnectionEvent> get connectionEvents =>
      _eventController.stream;

  @override
  UnboundedStats build() {
    ref.onDispose(_eventController.close);
    return const UnboundedStats();
  }

  /// Called by [AppEventNotifier] whenever an `unbounded-connection` event
  /// arrives from the Go bridge.
  void onConnectionEvent(UnboundedConnectionEvent event) {
    final s = state;
    if (event.state == 1) {
      state = UnboundedStats(
        activeCount: s.activeCount + 1,
        totalCount: s.totalCount + 1,
      );
    } else if (event.state == -1) {
      state = UnboundedStats(
        activeCount: (s.activeCount - 1).clamp(0, s.activeCount),
        totalCount: s.totalCount,
      );
    }
    _eventController.add(event);
  }
}
