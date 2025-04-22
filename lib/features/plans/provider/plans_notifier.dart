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
    final local = _getPlansFromLocalStorage();

    // If local exists, return it immediately and refresh in background
    if (local != null) {
      _refreshInBackground();
      state = AsyncData(local);
      return local;
    }
    // No local — fetch from API
    return await _fetchAndStorePlans();
  }

  PlansData? _getPlansFromLocalStorage() {
    final localPlans = sl<LocalStorageService>().getPlans();
    if (localPlans != null) {
      return localPlans.toPlanData();
    }
    return null;
  }

  Future<void> _refreshInBackground() async {
    final result = await ref.read(lanternServiceProvider).plans();
    result.fold(
      (error) => appLogger.error('Error refreshing plans in bg: $error'),
      (remote) async {
        await _storePlansLocally(remote);
        state = AsyncData(remote);
      },
    );
  }

  Future<PlansData> _fetchAndStorePlans() async {
    final result = await ref.read(lanternServiceProvider).plans();

    return await result.fold(
      (error) {
        appLogger.error('Error fetching plans: $error');
        throw Exception('Plans fetch failed');
      },
      (remote) async {
        await _storePlansLocally(remote);
        return remote;
      },
    );
  }

  Future<void> _storePlansLocally(PlansData plans) async {
    sl<LocalStorageService>().savePlans(plans.toEntity());
  }
}
