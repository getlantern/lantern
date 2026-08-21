import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/utils/storage_utils.dart';

const _environmentOverride = String.fromEnvironment('RADIANCE_ENV');

/// Returns the Radiance backend selected for this process.
Future<String> radianceEnvironment() async {
  return resolveRadianceEnvironment(
    buildOverride: _environmentOverride,
    releaseMode: kReleaseMode,
    stagingMarkerExists: () async {
      final directory = await AppStorageUtils.getAppDirectory();
      final marker = File('${directory.path}/.radiance_env');
      return marker.exists();
    },
  );
}

@visibleForTesting
Future<String> resolveRadianceEnvironment({
  required String buildOverride,
  required bool releaseMode,
  required Future<bool> Function() stagingMarkerExists,
}) async {
  if (buildOverride.isNotEmpty) {
    return normalizeRadianceEnvironment(buildOverride);
  }
  if (releaseMode) {
    return 'prod';
  }
  return await stagingMarkerExists() ? 'stage' : 'prod';
}

@visibleForTesting
String normalizeRadianceEnvironment(String value) {
  switch (value.trim().toLowerCase()) {
    case 'prod':
      return 'prod';
    case 'staging':
      return 'stage';
    default:
      throw ArgumentError.value(
        value,
        'RADIANCE_ENV',
        'unsupported environment',
      );
  }
}
