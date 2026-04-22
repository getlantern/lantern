import 'package:flutter/foundation.dart';

/// Snapshot of the radiance-daemon settings and env vars surfaced on the
/// developer screen. `loading` is true while the initial fetch is in flight.
@immutable
class DeveloperDaemonState {
  final String logLevel;
  final bool configFetchEnabled;
  final String country;
  final String version;
  final String featureOverrides;
  final bool loading;

  const DeveloperDaemonState({
    this.logLevel = 'info',
    this.configFetchEnabled = true,
    this.country = '',
    this.version = '',
    this.featureOverrides = '',
    this.loading = true,
  });

  DeveloperDaemonState copyWith({
    String? logLevel,
    bool? configFetchEnabled,
    String? country,
    String? version,
    String? featureOverrides,
    bool? loading,
  }) {
    return DeveloperDaemonState(
      logLevel: logLevel ?? this.logLevel,
      configFetchEnabled: configFetchEnabled ?? this.configFetchEnabled,
      country: country ?? this.country,
      version: version ?? this.version,
      featureOverrides: featureOverrides ?? this.featureOverrides,
      loading: loading ?? this.loading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeveloperDaemonState &&
          logLevel == other.logLevel &&
          configFetchEnabled == other.configFetchEnabled &&
          country == other.country &&
          version == other.version &&
          featureOverrides == other.featureOverrides &&
          loading == other.loading;

  @override
  int get hashCode => Object.hash(
        logLevel,
        configFetchEnabled,
        country,
        version,
        featureOverrides,
        loading,
      );
}
