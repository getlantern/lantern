import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/usage_stats.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'usage_stats_notifier.g.dart';

/// The on-device usage stats the Usage stats screen shows. Auto-disposed, so
/// nothing reads them once the screen closes.
@riverpod
class UsageStatsNotifier extends _$UsageStatsNotifier {
  /// The reload running, if any. Reloads never overlap: each is an IPC call,
  /// and on desktop its own isolate.
  Future<void>? _reloading;

  /// Bumped by each build, so a reload started before a retry can't write
  /// over it.
  int _generation = 0;

  @override
  Future<UsageStats> build() async {
    _generation++;
    final service = ref.read(lanternServiceProvider);
    await service.waitForRadiance();
    final result = await service.getUsageStats();
    return result.fold(
      (failure) => throw Exception('Failed to fetch usage stats: $failure'),
      (stats) => stats,
    );
  }

  /// Reloads the stats, unless a load (the first, or a retry) or another
  /// reload is still running. A failure keeps the stats already shown.
  Future<void> refresh() async {
    // Only build sets loading, and a failed retry keeps the previous value,
    // so this checks loading alone.
    if (state.isLoading) return;
    if (_reloading != null) return;
    await _reload(keepOnError: true);
  }

  /// Resets the stats, then reloads them. If that reload fails the screen
  /// shows the failure, since the stats it had are gone.
  ///
  /// A reset that fails, say on the call's deadline, may still have happened
  /// in the daemon, so the stats reload anyway, and a reset they show counts
  /// as success.
  Future<Either<Failure, Unit>> reset() async {
    final resetBefore = state.value?.resetAt;
    final result = await ref.read(lanternServiceProvider).resetUsageStats();
    if (!ref.mounted) return result;
    if (result.isRight()) {
      await _reload(keepOnError: false);
      return result;
    }
    await _reload(keepOnError: true);
    if (!ref.mounted) return result;
    final resetAfter = state.value?.resetAt;
    if (resetAfter != null && resetAfter != resetBefore) return right(unit);
    return result;
  }

  Future<void> _reload({required bool keepOnError}) async {
    // A reload already running may have read the stats before a reset, so a
    // reset's reload waits for it and then reads them again.
    while (_reloading != null) {
      await _reloading;
    }
    if (!ref.mounted) return;
    final reload = _fetch(keepOnError: keepOnError);
    _reloading = reload;
    try {
      await reload;
    } finally {
      if (identical(_reloading, reload)) _reloading = null;
    }
  }

  Future<void> _fetch({required bool keepOnError}) async {
    final generation = _generation;
    final result = await ref.read(lanternServiceProvider).getUsageStats();
    if (!ref.mounted || generation != _generation) return;
    result.match((failure) {
      if (!keepOnError || !state.hasValue) {
        state = AsyncError(failure, StackTrace.current);
      }
    }, (stats) => state = AsyncData(stats));
  }
}
