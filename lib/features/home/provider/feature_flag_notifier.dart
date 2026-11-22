import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feature_flag_notifier.g.dart';

@Riverpod(keepAlive: true)
class FeatureFlagNotifier extends _$FeatureFlagNotifier {
  @override
  Map<String, dynamic> build() {
    fetchFeatureFlags();
    return {};
  }

  /// Counts fetches, so a slower one never replaces a newer one's flags.
  int _fetches = 0;

  Future<void> fetchFeatureFlags() async {
    appLogger.debug('Fetching feature flags...');
    final fetch = ++_fetches;
    final result = await ref.read(lanternServiceProvider).featureFlag();
    if (!ref.mounted || fetch != _fetches) return;
    result.fold(
      (failure) {
        appLogger.error('Error fetching feature flags: ${failure.error}');
      },
      (flags) {
        try {
          final next = json.decode(flags) as Map<String, dynamic>;
          // Unchanged flags keep the same map, so watchers don't rebuild.
          if (mapEquals(next, state)) return;
          state = next;
          appLogger.debug('Feature flags fetched successfully: $state');
        } catch (e, st) {
          appLogger.error('Failed to parse feature flags', e, st);
        }
      },
    );
  }
}
