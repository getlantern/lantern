import 'dart:async';
import 'dart:convert';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'plans_notifier.g.dart';

@Riverpod()
class PlansNotifier extends _$PlansNotifier {
  static const _prefsKey = 'plans_json';
  final _storage = LocalStorageService();

  Plan? userSelectedPlan;

  @override
  Future<PlansData> build() async {
    state = const AsyncLoading();
    final cached = await _getPlansFromPrefs();
    if (cached != null) {
      unawaited(_refreshInBackground());
      state = AsyncData(cached);
      return cached;
    }

    return fetchPlans();
  }

  Future<PlansData?> _getPlansFromPrefs() async {
    try {
      final raw = await _storage.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PlansData.fromJson(decoded);
    } catch (e, st) {
      appLogger.error('Error reading cached plans from prefs', e, st);
      return null;
    }
  }

  Future<void> _savePlansToPrefs(PlansData plans) async {
    try {
      await _storage.setString(_prefsKey, jsonEncode(plans.toJson()));
    } catch (e, st) {
      appLogger.error('Error saving plans to prefs', e, st);
    }
  }

  Future<PlansData> fetchPlans({bool fromBackground = false}) async {
    if (!fromBackground) {
      state = const AsyncLoading();
    }
    final result = await ref.read(lanternServiceProvider).plans();
    return result.fold(
      (error) {
        if (fromBackground) {
          appLogger.error('Error fetching plans in background: $error');
          return state.value ?? (throw Exception('Plans fetch failed'));
        }
        state = AsyncError(error, StackTrace.current);
        throw Exception('Plans fetch failed');
      },
      (remote) {
        unawaited(_savePlansToPrefs(remote));
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

  Future<PlansData?> getPlanData() => _getPlansFromPrefs();
}
