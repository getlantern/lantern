import 'dart:async';

typedef LatestAsyncQueueWorker<T, R> = Future<R> Function(T value);

/// Serializes async updates and coalesces queued values so only the latest
/// pending value is processed after each await point.
class LatestAsyncQueue<T, R> {
  LatestAsyncQueue({
    required LatestAsyncQueueWorker<T, R> worker,
    required this.defaultResult,
  }) : _worker = worker;

  final LatestAsyncQueueWorker<T, R> _worker;
  final R defaultResult;

  bool _running = false;
  bool _hasPending = false;
  late T _pendingValue;
  Completer<R>? _cycleCompleter;

  bool get isRunning => _running;

  Future<R> enqueue(T value) {
    _pendingValue = value;
    _hasPending = true;
    _cycleCompleter ??= Completer<R>();

    if (_running) {
      return _cycleCompleter!.future;
    }

    return _drainCurrentCycle();
  }

  Future<R> _drainCurrentCycle() async {
    _running = true;
    final completer = _cycleCompleter!;
    var cycleResult = defaultResult;

    try {
      while (_hasPending) {
        final value = _pendingValue;
        _hasPending = false;
        cycleResult = await _worker(value);
      }

      if (!completer.isCompleted) {
        completer.complete(cycleResult);
      }
      return cycleResult;
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      _running = false;
      if (identical(_cycleCompleter, completer)) {
        _cycleCompleter = null;
      }
    }
  }
}
