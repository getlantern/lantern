import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/mapper/plan_mapper.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  Plan? userSelectedPlan;

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
    final plans = await fetchPlans();
    state = AsyncData(plans);
    await _storePlansLocally(plans);
    return plans;
  }

  PlansData? _getPlansFromLocalStorage() {
    try {
      final localPlans = sl<LocalStorageService>().getPlans();
      if (localPlans != null) {
        return localPlans.toPlanData();
      }
      return null;
    } catch (e, s) {
      appLogger.error('Error getting local plans: $e', e, s);
      return null;
    }
  }

  Future<PlansData> fetchPlans({bool fromBackground = false}) async {
    state = AsyncLoading();
    final result = await ref.read(lanternServiceProvider).plans();
    return await result.fold(
      (error) {
        if (fromBackground) {
          appLogger.error('Error fetching plans in background: $error');
          // Since we already have plans in local storage, we can return them
          return _getPlansFromLocalStorage()!;
        }
        state = AsyncError(error, StackTrace.current);
        appLogger.error('Error fetching plans: $error');
        throw Exception('Plans fetch failed');
      },
      (remote) async {
        return remote;
      },
    );
  }

  Future<void> _storePlansLocally(PlansData plans) async {
    sl<LocalStorageService>().savePlans(plans.toEntity());
  }

  Future<void> _refreshInBackground() async {
    final remotePlans = await fetchPlans(fromBackground: true);
    await _storePlansLocally(remotePlans);
    state = AsyncData(remotePlans);
  }

  void setSelectedPlan(Plan plan) {
    userSelectedPlan = plan;
  }

  Plan getSelectedPlan() {
    return userSelectedPlan!;
  }

  PlansData getPlanData() {
    final plansData = _getPlansFromLocalStorage()!;
    return plansData;
  }
}
