import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_eum.dart';

/// Immutable snapshot of radiance-backed VPN preferences.
///
/// Fields default to safe "off"/full-tunnel values so callers can read them
/// synchronously at app start while the real values are being fetched from
/// the native layer in the background.
@immutable
class RadianceSettingsState {
  final bool blockAds;
  final RoutingMode routingMode;
  final bool splitTunneling;
  final bool telemetry;

  const RadianceSettingsState({
    this.blockAds = false,
    this.routingMode = RoutingMode.full,
    this.splitTunneling = false,
    this.telemetry = false,
  });

  RadianceSettingsState copyWith({
    bool? blockAds,
    RoutingMode? routingMode,
    bool? splitTunneling,
    bool? telemetry,
  }) {
    return RadianceSettingsState(
      blockAds: blockAds ?? this.blockAds,
      routingMode: routingMode ?? this.routingMode,
      splitTunneling: splitTunneling ?? this.splitTunneling,
      telemetry: telemetry ?? this.telemetry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadianceSettingsState &&
          blockAds == other.blockAds &&
          routingMode == other.routingMode &&
          splitTunneling == other.splitTunneling &&
          telemetry == other.telemetry;

  @override
  int get hashCode =>
      Object.hash(blockAds, routingMode, splitTunneling, telemetry);
}
