class AvailableServers {
  final List<Server> servers;

  AvailableServers(this.servers);

  factory AvailableServers.fromJson(List<dynamic> json) => AvailableServers(
    json.map((e) => Server.fromJson(e as Map<String, dynamic>)).toList(),
  );

  List<Server> get lanternServers => servers.where((s) => s.isLantern).toList();

  List<Server> get userServers => servers.where((s) => !s.isLantern).toList();

  /// One representative Lantern server per country/city. If any server for the
  /// location has a successful probe, use the fastest one. Otherwise prefer a
  /// server without failed-probe evidence so untested locations are not shown as
  /// unavailable.
  List<Server> get lanternServerLocations {
    final grouped = <String, List<Server>>{};
    for (final server in lanternServers) {
      grouped.putIfAbsent(_locationKey(server), () => <Server>[]).add(server);
    }

    return grouped.values.map(_bestServerForLocation).toList()
      ..sort(_compareServersByLocation);
  }

  bool get hasUserServers => servers.any((s) => !s.isLantern);

  Server? serverByTag(String tag) {
    for (final server in servers) {
      if (server.tag == tag) return server;
    }
    return null;
  }

  /// Lantern server with the lowest successful probe delay. Null when no
  /// Lantern server has a successful probe.
  Server? get fastestLanternServer {
    final ranked = lanternServers.where((s) => s.hasSuccessfulProbe).toList()
      ..sort(
        (a, b) => a.selectionHistory!.lastSuccessDelayMs.compareTo(
          b.selectionHistory!.lastSuccessDelayMs,
        ),
      );
    return ranked.isEmpty ? null : ranked.first;
  }
}

const _manualSelectionFailureWarningThreshold = 3;

String _locationKey(Server server) {
  final location = server.location;
  return [
    location.countryCode.trim().toUpperCase(),
    location.country.trim().toLowerCase(),
    location.city.trim().toLowerCase(),
  ].join('|');
}

Server _bestServerForLocation(List<Server> servers) {
  final successful = servers.where((s) => s.hasSuccessfulProbe).toList();
  if (successful.isNotEmpty) {
    successful.sort((a, b) {
      final delay = a.selectionHistory!.lastSuccessDelayMs.compareTo(
        b.selectionHistory!.lastSuccessDelayMs,
      );
      if (delay != 0) return delay;
      return a.tag.compareTo(b.tag);
    });
    return successful.first;
  }

  final notFailed = servers
      .where((s) => !s.shouldWarnBeforeManualSelection)
      .toList();
  final sorted = (notFailed.isEmpty ? [...servers] : notFailed)
    ..sort(_compareServersByLocation);
  return sorted.first;
}

int _compareServersByLocation(Server a, Server b) {
  final country = a.location.country.compareTo(b.location.country);
  if (country != 0) return country;
  final city = a.location.city.compareTo(b.location.city);
  if (city != 0) return city;
  return a.tag.compareTo(b.tag);
}

class Server {
  final String tag;
  final String type;
  final bool isLantern;
  final Map<String, dynamic>? outbound;
  final Map<String, dynamic>? endpoint;
  final GeoLocation location;
  final ServerCredential? credentials;
  final SelectionHistory? selectionHistory;

  Server({
    required this.tag,
    required this.type,
    required this.isLantern,
    this.outbound,
    this.endpoint,
    required this.location,
    this.credentials,
    this.selectionHistory,
  });

  factory Server.fromJson(Map<String, dynamic> json) => Server(
    tag: json['tag'] ?? '',
    type: json['type'] ?? '',
    isLantern: json['isLantern'] ?? false,
    outbound: json['outbound'] as Map<String, dynamic>?,
    endpoint: json['endpoint'] as Map<String, dynamic>?,
    location: GeoLocation.fromJson(
      (json['location'] as Map<String, dynamic>?) ?? const {},
    ),
    credentials: json['credentials'] != null
        ? ServerCredential.fromJson(json['credentials'] as Map<String, dynamic>)
        : null,
    selectionHistory: json["selection_history"] == null
        ? null
        : SelectionHistory.fromJson(json["selection_history"]),
  );

  /// IP address extracted from outbound or endpoint options.
  String get serverIP =>
      outbound?['server'] as String? ?? endpoint?['server'] as String? ?? '';

  bool get hasSuccessfulProbe =>
      (selectionHistory?.lastSuccessDelayMs ?? 0) > 0;

  bool get hasFailedProbeEvidence =>
      (selectionHistory?.consecutiveFailures ?? 0) >=
      _manualSelectionFailureWarningThreshold;

  /// Manual mode pins traffic to exactly this server. Warn only after URL tests
  /// have produced enough failed probe evidence; missing probe data means
  /// unknown/untested, not unreachable.
  bool get shouldWarnBeforeManualSelection =>
      isLantern && hasFailedProbeEvidence;
}

class GeoLocation {
  final String country;
  final String countryCode;
  final String city;
  final double latitude;
  final double longitude;

  GeoLocation({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
    country: json['country'] ?? '',
    countryCode: json['country_code'] ?? '',
    city: json['city'] ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
  );
}

class ServerCredential {
  final String accessToken;
  final bool isJoined;
  final String port;

  ServerCredential({
    required this.accessToken,
    required this.isJoined,
    required this.port,
  });

  factory ServerCredential.fromJson(Map<String, dynamic> json) =>
      ServerCredential(
        accessToken: json['access_token'] ?? '',
        isJoined: json['is_joined'] ?? false,
        port: json['port']?.toString() ?? '',
      );
}

/// SelectionHistory mirrors radiance's per-server selection history. Probe
/// outcomes feed [lastSuccessDelayMs]/[consecutiveFailures]; real user-traffic
/// failures feed [userFailures], kept separate so a censor that passes the
/// probe URL while dropping user traffic is still visible.
class SelectionHistory {
  /// Most recent successful probe RTT in milliseconds. 0 means no successful
  /// probe yet, used as the sentinel by [Server.hasSuccessfulProbe].
  final int lastSuccessDelayMs;

  /// Timestamp of the most recent probe outcome, success or failure.
  final DateTime? lastOutcomeAt;

  /// Probe failures since the last probe success; resets on success.
  final int consecutiveFailures;

  /// Sliding window of user-traffic failure timestamps. Probe successes never
  /// enter this window.
  final List<DateTime> userFailures;

  final DateTime? updatedAt;

  SelectionHistory({
    this.lastSuccessDelayMs = 0,
    this.lastOutcomeAt,
    this.consecutiveFailures = 0,
    this.userFailures = const [],
    this.updatedAt,
  });

  factory SelectionHistory.fromJson(Map<String, dynamic> json) =>
      SelectionHistory(
        lastSuccessDelayMs: json["last_success_delay_ms"] ?? 0,
        lastOutcomeAt: json["last_outcome_at"] == null
            ? null
            : DateTime.parse(json["last_outcome_at"]),
        consecutiveFailures: json["consecutive_failures"] ?? 0,
        userFailures:
            (json["user_failures"] as List<dynamic>?)
                ?.map((e) => DateTime.parse(e as String))
                .toList() ??
            const [],
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
    "last_success_delay_ms": lastSuccessDelayMs,
    if (lastOutcomeAt != null)
      "last_outcome_at": lastOutcomeAt!.toIso8601String(),
    "consecutive_failures": consecutiveFailures,
    if (userFailures.isNotEmpty)
      "user_failures": userFailures.map((e) => e.toIso8601String()).toList(),
    if (updatedAt != null) "updated_at": updatedAt!.toIso8601String(),
  };
}
