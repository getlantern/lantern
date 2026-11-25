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

  /// Numbers fetches, and records the newest whose flags were applied, so a
  /// slower fetch never replaces a newer one's flags and a failed fetch
  /// leaves the last good ones.
  int _fetches = 0;
  int _applied = 0;

  Future<void> fetchFeatureFlags() async {
    appLogger.debug('Fetching feature flags...');
    final fetch = ++_fetches;
    final result = await ref.read(lanternServiceProvider).featureFlag();
    // An older fetch may only fill flags that have not loaded yet: once any
    // fetch has applied, only a newer one may replace them.
    if (!ref.mounted || fetch < _applied) return;
    if (fetch < _fetches && _applied > 0) return;
    result.fold(
      (failure) {
        appLogger.error('Error fetching feature flags: ${failure.error}');
      },
      (flags) {
        try {
          final next = json.decode(flags) as Map<String, dynamic>;
          _applied = fetch;
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
