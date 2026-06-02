class AvailableServers {
  final List<Server> servers;

  AvailableServers(this.servers);

  factory AvailableServers.fromJson(List<dynamic> json) => AvailableServers(
    json.map((e) => Server.fromJson(e as Map<String, dynamic>)).toList(),
  );

  List<Server> get lanternServers => servers.where((s) => s.isLantern).toList();

  List<Server> get userServers => servers.where((s) => !s.isLantern).toList();

  bool get hasUserServers => servers.any((s) => !s.isLantern);

  Server? serverByTag(String tag) {
    for (final server in servers) {
      if (server.tag == tag) return server;
    }
    return null;
  }

  /// Lantern server with the lowest successful URL-test delay. Null when no
  /// Lantern server has a successful probe.
  Server? get fastestLanternServer {
    final ranked = lanternServers.where((s) => s.hasSuccessfulProbe).toList()
      ..sort(
        (a, b) => a.urlTestResult!.delay.compareTo(b.urlTestResult!.delay),
      );
    return ranked.isEmpty ? null : ranked.first;
  }
}

class Server {
  final String tag;
  final String type;
  final bool isLantern;
  final Map<String, dynamic>? outbound;
  final Map<String, dynamic>? endpoint;
  final GeoLocation location;
  final ServerCredential? credentials;
  final UrlTestResult? urlTestResult;

  Server({
    required this.tag,
    required this.type,
    required this.isLantern,
    this.outbound,
    this.endpoint,
    required this.location,
    this.credentials,
    this.urlTestResult,
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
    urlTestResult: json["urlTestResult"] == null
        ? null
        : UrlTestResult.fromJson(json["urlTestResult"]),
  );

  /// IP address extracted from outbound or endpoint options.
  String get serverIP =>
      outbound?['server'] as String? ?? endpoint?['server'] as String? ?? '';

  bool get hasSuccessfulProbe => (urlTestResult?.delay ?? 0) > 0;

  /// Manual mode pins traffic to exactly this server. If Smart Location has no
  /// successful probe for it, warn before pinning so users can stay on auto.
  bool get shouldWarnBeforeManualSelection => isLantern && !hasSuccessfulProbe;
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

class UrlTestResult {
  int delay;
  DateTime time;

  UrlTestResult({required this.delay, required this.time});

  factory UrlTestResult.fromJson(Map<String, dynamic> json) =>
      UrlTestResult(delay: json["delay"], time: DateTime.parse(json["time"]));

  Map<String, dynamic> toJson() => {
    "delay": delay,
    "time": time.toIso8601String(),
  };
}
