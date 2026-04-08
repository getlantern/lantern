class AvailableServers {
  final List<Server> servers;

  AvailableServers(this.servers);

  factory AvailableServers.fromJson(List<dynamic> json) =>
      AvailableServers(json
          .map((e) => Server.fromJson(e as Map<String, dynamic>))
          .toList());

  List<Server> get lanternServers =>
      servers.where((s) => s.isLantern).toList();

  List<Server> get userServers =>
      servers.where((s) => !s.isLantern).toList();

  bool get hasUserServers => servers.any((s) => !s.isLantern);
}

class Server {
  final String tag;
  final String type;
  final bool isLantern;
  final Map<String, dynamic>? outbound;
  final Map<String, dynamic>? endpoint;
  final GeoLocation location;
  final ServerCredential? credentials;

  Server({
    required this.tag,
    required this.type,
    required this.isLantern,
    this.outbound,
    this.endpoint,
    required this.location,
    this.credentials,
  });

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        tag: json['tag'] ?? '',
        type: json['type'] ?? '',
        isLantern: json['isLantern'] ?? false,
        outbound: json['outbound'] as Map<String, dynamic>?,
        endpoint: json['endpoint'] as Map<String, dynamic>?,
        location: GeoLocation.fromJson(
            (json['location'] as Map<String, dynamic>?) ?? const {}),
        credentials: json['credentials'] != null
            ? ServerCredential.fromJson(
                json['credentials'] as Map<String, dynamic>)
            : null,
      );

  /// IP address extracted from outbound or endpoint options.
  String get serverIP =>
      outbound?['server'] as String? ??
      endpoint?['server'] as String? ??
      '';
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
