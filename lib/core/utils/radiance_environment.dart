import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/utils/storage_utils.dart';

const _environmentOverride = String.fromEnvironment('RADIANCE_ENV');

/// Returns the Radiance backend selected for this process.
Future<String> radianceEnvironment() async {
  if (_environmentOverride.isNotEmpty) {
    return normalizeRadianceEnvironment(_environmentOverride);
  }
  if (kReleaseMode) {
    return 'prod';
  }
  final directory = await AppStorageUtils.getAppDirectory();
  final marker = File('${directory.path}/.radiance_env');
  return await marker.exists() ? 'stage' : 'prod';
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
