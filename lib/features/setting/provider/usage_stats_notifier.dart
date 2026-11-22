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

  @override
  Future<UsageStats> build() async {
    final service = ref.read(lanternServiceProvider);
    await service.waitForRadiance();
    final result = await service.getUsageStats();
    return result.fold(
      (failure) => throw Exception('Failed to fetch usage stats: $failure'),
      (stats) => stats,
    );
  }

  /// Reloads the stats, unless the first load or another reload is still
  /// running. A failure keeps the stats already shown.
  Future<void> refresh() async {
    if (state.isLoading && !state.hasValue) return;
    if (_reloading != null) return;
    await _reload(keepOnError: true);
  }

  /// Resets the stats, then reloads them. If that reload fails the screen
  /// shows the failure, since the stats it had are gone.
  Future<Either<Failure, Unit>> reset() async {
    final result = await ref.read(lanternServiceProvider).resetUsageStats();
    if (result.isRight() && ref.mounted) await _reload(keepOnError: false);
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
    final result = await ref.read(lanternServiceProvider).getUsageStats();
    if (!ref.mounted) return;
    result.match((failure) {
      if (!keepOnError || !state.hasValue) {
        state = AsyncError(failure, StackTrace.current);
      }
    }, (stats) => state = AsyncData(stats));
  }
}
