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
  final bool telemetry;
  final bool peerProxy;
  // Local opt-in for the broflake / Unbounded widget proxy. Separate
  // from peerProxy because the two are independent toggles — the SmC
  // disclosure dialog flips just one of them based on the user's
  // choice ("Basic mode" → unboundedEnabled, "Full mode" → peerProxy).
  // The VPN settings tile uses BOTH to decide whether to show the
  // "On — tap to view" subtitle.
  final bool unboundedEnabled;

  const RadianceSettingsState({
    this.blockAds = false,
    this.routingMode = RoutingMode.full,
    this.telemetry = false,
    this.peerProxy = false,
    this.unboundedEnabled = false,
  });

  RadianceSettingsState copyWith({
    bool? blockAds,
    RoutingMode? routingMode,
    bool? telemetry,
    bool? peerProxy,
    bool? unboundedEnabled,
  }) {
    return RadianceSettingsState(
      blockAds: blockAds ?? this.blockAds,
      routingMode: routingMode ?? this.routingMode,
      telemetry: telemetry ?? this.telemetry,
      peerProxy: peerProxy ?? this.peerProxy,
      unboundedEnabled: unboundedEnabled ?? this.unboundedEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadianceSettingsState &&
          blockAds == other.blockAds &&
          routingMode == other.routingMode &&
          telemetry == other.telemetry &&
          peerProxy == other.peerProxy &&
          unboundedEnabled == other.unboundedEnabled;

  @override
  int get hashCode => Object.hash(
        blockAds,
        routingMode,
        telemetry,
        peerProxy,
        unboundedEnabled,
      );
}
