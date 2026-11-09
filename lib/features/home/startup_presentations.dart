import 'package:lantern/core/common/common.dart';

/// Home's startup presentations (the referral and renewal popups, the
/// Personal Proxies introduction), shown one at a time: each step starts
/// once the one before it has finished, so whichever comes first, the
/// others wait for it to close. Steps left when Home goes away never run.
class StartupPresentations {
  Future<void> _tail = Future.value();
  bool _closed = false;

  /// Queues [step] behind the steps already queued.
  void add(Future<void> Function() step) {
    _tail = _tail.then((_) async {
      if (_closed) return;
      try {
        await step();
      } catch (e, st) {
        appLogger.error('Startup presentation failed', e, st);
      }
    });
  }

  /// Stops steps that have not started yet from running.
  void close() => _closed = true;
}
