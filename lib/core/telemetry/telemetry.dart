import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lantern/core/services/logger_service.dart';

/// A named telemetry event. Feature event enums implement this.
abstract interface class TelemetryEvent {
  String get tag;
}

void trackEvent(
  TelemetryEvent event, [
  Map<String, Object?> properties = const {},
]) => logTelemetry(event.tag, properties);

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
  // Values JSON can't encode are logged as strings, so a telemetry call
  // never throws into the flow it is reporting on.
  final json = jsonEncode(sanitized, toEncodable: (value) => '$value');
  return 'telemetry event=$event properties=$json';
}
