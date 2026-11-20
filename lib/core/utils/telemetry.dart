import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/services/logger_service.dart';

/// Writes a structured `telemetry event=... properties=...` line to the app
/// log. These lines stay on the device and travel with issue reports.
void logTelemetry(String event, Map<String, Object?> properties) {
  appLogger.info(telemetryLine(event, properties));
}

@visibleForTesting
String telemetryLine(String event, Map<String, Object?> properties) {
  final sanitized = <String, Object?>{
    for (final entry in properties.entries)
      if (entry.value != null) entry.key: entry.value,
  };
  return 'telemetry event=$event properties=${jsonEncode(sanitized)}';
}
