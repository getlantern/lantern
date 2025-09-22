import 'dart:convert';

import 'package:lantern/core/models/feature_flags.dart';
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

  Future<void> fetchFeatureFlags() async {
    appLogger.debug('Fetching feature flags...');
    final result = await ref.read(lanternServiceProvider).featureFlag();
    result.fold(
      (failure) {
        appLogger.error(
            'Error fetching feature flags: ${failure.localizedErrorMessage}');
      },
      (flags) {
        try {
          state = json.decode(flags) as Map<String, dynamic>;
          appLogger.debug('Feature flags fetched successfully: $state');
        } catch (e, st) {
          appLogger.error('Failed to parse feature flags', e, st);
        }
      },
    );
  }

  bool get isSentryEnabled =>
      state.getBool(FeatureFlag.sentry, defaultValue: false);

  // bool get isGCPEnabled => state.getBool(FeatureFlag.privateGcp, defaultValue: false);
  bool get isGCPEnabled => true;
}
