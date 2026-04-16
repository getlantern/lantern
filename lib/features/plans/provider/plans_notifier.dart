import 'dart:async';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  Plan? userSelectedPlan;

  @override
  Future<PlansData> build() async {
    state = const AsyncLoading();
    final cached = _storage.getPlans();
    if (cached != null) {
      unawaited(_refreshInBackground());
      state = AsyncData(cached);
      return cached;
    }

    return fetchPlans();
  }

  Future<PlansData> fetchPlans({bool fromBackground = false}) async {
    return _fetchPlansWithRetry(
        fromBackground: fromBackground, attempt: 0);
  }

  Future<PlansData> _fetchPlansWithRetry({
    required bool fromBackground,
    required int attempt,
  }) async {
    if (!fromBackground && attempt == 0) {
      state = const AsyncLoading();
    }
    final result = await ref.read(lanternServiceProvider).plans();
    return result.fold(
      (error) {
        if (fromBackground) {
          appLogger.error('Error fetching plans in background: $error');
          return state.value ?? (throw Exception('Plans fetch failed'));
        }
        // Retry up to 2 times with increasing delay — the first attempt
        // often fails at startup before radiance is fully ready.
        if (attempt < 2) {
          appLogger.info(
              'Plans fetch failed, retrying (${attempt + 1}/2)...');
          return Future.delayed(
            Duration(seconds: 2 * (attempt + 1)),
            () => _fetchPlansWithRetry(
                fromBackground: false, attempt: attempt + 1),
          );
        }
        state = AsyncError(error, StackTrace.current);
        throw Exception('Plans fetch failed');
      },
      (remote) {
        unawaited(_storage.savePlans(remote));
        return remote;
      },
    );
  }

  Future<void> _refreshInBackground() async {
    appLogger.info('Refreshing plans in background');
    final remotePlans = await fetchPlans(fromBackground: true);
    state = AsyncData(remotePlans);
  }

  void setSelectedPlan(Plan plan) => userSelectedPlan = plan;

  Plan getSelectedPlan() => userSelectedPlan!;
}
