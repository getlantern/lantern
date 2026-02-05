import 'dart:async';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  Plan? userSelectedPlan;

  @override
  Future<PlansData> build() async {
    state = const AsyncLoading();

    final cached = await _getPlansFromGoCache();
    if (cached != null) {
      unawaited(_refreshInBackground());
      state = AsyncData(cached);
      return cached;
    }

    final plans = await fetchPlans();
    state = AsyncData(plans);
    await _storePlansInGoCache(plans);
    return plans;
  }

  Future<PlansData?> _getPlansFromGoCache() async {
    try {
      final result = await ref.read(lanternServiceProvider).getCachedPlans();
      return result.fold(
        (err) {
          appLogger.warning('Error getting cached plans from Go: $err');
          return null;
        },
        (plans) => plans,
      );
    } catch (e, s) {
      appLogger.error('Error getting cached plans from Go: $e', e, s);
      return null;
    }
  }

  Future<PlansData> fetchPlans({bool fromBackground = false}) async {
    if (!fromBackground) {
      state = const AsyncLoading();
    }

    final result = await ref.read(lanternServiceProvider).plans();
    return await result.fold(
      (error) async {
        if (fromBackground) {
          appLogger.error('Error fetching plans in background: $error');
          final cached = await _getPlansFromGoCache();
          if (cached != null) return cached;
        }
        state = AsyncError(error, StackTrace.current);
        throw Exception('Plans fetch failed');
      },
      (remote) async => remote,
    );
  }

  Future<void> _storePlansInGoCache(PlansData plans) async {
    final res = await ref.read(lanternServiceProvider).setCachedPlans(plans);
    res.fold(
      (e) => appLogger.warning('Failed to persist plans in Go cache: $e'),
      (_) {},
    );
  }

  Future<void> _refreshInBackground() async {
    appLogger.info('Refreshing plans in background');
    final remotePlans = await fetchPlans(fromBackground: true);
    await _storePlansInGoCache(remotePlans);
    state = AsyncData(remotePlans);
  }

  void setSelectedPlan(Plan plan) => userSelectedPlan = plan;

  Plan getSelectedPlan() => userSelectedPlan!;

  Future<PlansData?> getPlanData() => _getPlansFromGoCache();
}
