import 'dart:convert';
import 'dart:io';

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
    try {
      if (Platform.isWindows) return;
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
    } catch (_) {}
  }

  bool isGCPFlag() {
    final flags = state;
    if (flags.isEmpty) {
      appLogger.debug('Feature flags are empty, GCP is enable by default.');

      ///Since the flags are empty, we assume GCP is disable by default.
      /// Majority of out user are in censorship regions, so we assume GCP is not enable.
      /// This is a safe assumption to avoid breaking the app.
      return false;
    }
    final gcpEnabled = flags['private.gcp'] ?? false;
    appLogger.debug('GCP enabled: $gcpEnabled');
    return gcpEnabled;
  }
}
