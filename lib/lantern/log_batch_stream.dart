import 'dart:async';

import 'package:lantern/core/services/logger_service.dart';

final RegExp _newline = RegExp(r'\r?\n');

/// Log lines from the Go core, in batches, which Go sends only while [stream]
/// has a listener.
///
/// It listens to the port for as long as it exists, because a port holds
/// every message it receives until something reads it. Lines that arrive with
/// no listener are dropped.
class LogBatchStream {
  /// [setActive] turns Go's sending on or off. Calls run one at a time, in
  /// order.
  LogBatchStream(
    Stream<String> lines,
    Future<void> Function(bool active) setActive,
  ) : _setActive = setActive {
    _controller = StreamController<List<String>>.broadcast(
      onListen: () => _update(true),
      onCancel: () => _update(false),
    );
    lines.listen(_add);
  }

  final Future<void> Function(bool active) _setActive;
  late final StreamController<List<String>> _controller;
  Future<void> _updates = Future.value();

  Stream<List<String>> get stream => _controller.stream;

  void _add(String lines) {
    if (!_controller.hasListener) return;
    final batch = lines
        .split(_newline)
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    if (batch.isNotEmpty) _controller.add(batch);
  }

  void _update(bool active) {
    _updates = _updates
        .then((_) => _setActive(active))
        .onError(
          (e, st) => appLogger.warning('Failed to set log stream: $e', e, st),
        );
  }
}
