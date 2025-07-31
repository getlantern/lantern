import 'dart:convert';

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

  void fetchFeatureFlags() async {
    appLogger.debug('Fetching feature flags...');
    final result = await ref.read(lanternServiceProvider).featureFlag();
    result.fold(
      (failure) {
        // Handle failure, maybe log it or show a message
        appLogger.error(
            'Error fetching feature flags: ${failure.localizedErrorMessage}');
      },
      (flags) {
        state = json.decode(flags);
        appLogger.debug('Feature flags fetched successfully: $flags');
      },
    );
  }

  bool isGCPFlag() {
    final flags = state;
    if (flags.isEmpty) {
      appLogger.debug('Feature flags are empty, GCP is enable by default.');
      return true;
    }
    final gcpEnabled = flags['private.gcp'] ?? false;
    appLogger.debug('GCP enabled: $gcpEnabled');
    return gcpEnabled;
  }


}

