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

  /// Reloads the stats. A failure keeps the stats already shown.
  Future<void> refresh() async {
    final result = await ref.read(lanternServiceProvider).getUsageStats();
    if (!ref.mounted) return;
    result.match((failure) {
      if (!state.hasValue) state = AsyncError(failure, StackTrace.current);
    }, (stats) => state = AsyncData(stats));
  }

  Future<Either<Failure, Unit>> reset() async {
    final result = await ref.read(lanternServiceProvider).resetUsageStats();
    if (result.isRight() && ref.mounted) await refresh();
    return result;
  }
}
