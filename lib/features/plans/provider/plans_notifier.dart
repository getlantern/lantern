import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/plan_mapper.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  @override
  Future<PlansData> build() async {
    state = AsyncLoading();
    final local = _getPlansFromLocalStorage();
    // If local exists, return it immediately and refresh in background
    if (local != null) {
      _refreshInBackground();
      state = AsyncData(local);
      return local;
    }
    // No local — fetch from API
    final plans = await _fetchPlans();
    state = AsyncData(plans);
    return plans;
  }

  PlansData? _getPlansFromLocalStorage() {
    try {
      final localPlans = sl<LocalStorageService>().getPlans();
      if (localPlans != null) {
        return localPlans.toPlanData();
      }
      return null;
    } catch (e) {
      appLogger.error('Error getting local plans: $e');
      return null;
    }
  }

  Future<PlansData> _fetchPlans() async {
    final result = await ref.read(lanternServiceProvider).plans();
    return await result.fold(
      (error) {
        state = AsyncError(error, StackTrace.current);
        appLogger.error('Error fetching plans: $error');
        throw Exception('Plans fetch failed');
      },
      (remote) async {
        remote.plans.sort((a, b) {
          if (a.bestValue == b.bestValue) return 0;
          return a.bestValue ? -1 : 1;
        });
        return remote;
      },
    );
  }

  Future<void> _storePlansLocally(PlansData plans) async {
    sl<LocalStorageService>().savePlans(plans.toEntity());
  }

  Future<void> _refreshInBackground() async {
    final remotePlans = await _fetchPlans();
    await _storePlansLocally(remotePlans);
    state = AsyncData(remotePlans);
  }
}
