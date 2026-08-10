import 'dart:async';

/// Polls [fetch] until it returns a value or [timeout] expires.
///
/// A null result means the condition is not ready yet. Each fetch is bounded by
/// the remaining timeout so a stalled request cannot make the overall poll
/// unbounded.
Future<T?> boundedPoll<T>({
  required Future<T?> Function(int attempt) fetch,
  required Duration timeout,
  Duration initialDelay = Duration.zero,
  Duration interval = const Duration(seconds: 2),
}) async {
  if (timeout <= Duration.zero) return null;

  final stopwatch = Stopwatch()..start();
  if (initialDelay > Duration.zero) {
    final delay = initialDelay < timeout ? initialDelay : timeout;
    await Future.delayed(delay);
  }

  var attempt = 0;
  while (stopwatch.elapsed < timeout) {
    attempt++;
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) break;
    final result = await fetch(
      attempt,
    ).timeout(remaining, onTimeout: () => null);
    if (result != null) return result;

    final afterFetch = timeout - stopwatch.elapsed;
    if (afterFetch <= Duration.zero) break;
    final delay = interval < afterFetch ? interval : afterFetch;
    if (delay > Duration.zero) await Future.delayed(delay);
  }
  return null;
}
