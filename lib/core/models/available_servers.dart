class AvailableServers {
  Lantern lantern;
  Lantern user;

  AvailableServers({
    required this.lantern,
    required this.user,
  });

  factory AvailableServers.fromJson(Map<String, dynamic> json) =>
      AvailableServers(
        lantern: Lantern.fromJson(
            (json["lantern"] as Map<String, dynamic>?) ?? const {}),
        user: Lantern.fromJson(
            (json["user"] as Map<String, dynamic>?) ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        "lantern": lantern.toJson(),
        "user": user.toJson(),
      };
}

class Lantern {
  List<Endpoint> endpoints;
  List<Endpoint> outbounds;
  Map<String, Location_> locations;
  Map<String, ServerCredential> credentials;

  Lantern({
    required this.endpoints,
    required this.outbounds,
    required this.locations,
    required this.credentials,
  });

  factory Lantern.fromJson(Map<String, dynamic> json) => Lantern(
        endpoints: json["endpoints"] == null
            ? []
            : List<Endpoint>.from(
                (json["endpoints"] as List).map((x) => Endpoint.fromJson(x))),
        outbounds: json["outbounds"] == null
            ? []
            : List<Endpoint>.from(
                (json["outbounds"] as List).map((x) => Endpoint.fromJson(x))),
        locations: json["locations"] == null
            ? <String, Location_>{}
            : Map<String, Location_>.from(
                (json["locations"] as Map<String, dynamic>).map(
                  (k, v) => MapEntry(
                    k,
                    Location_.fromJson(v as Map<String, dynamic>)..tag = k,
                  ),
                ),
              ),
        credentials: json["credentials"] == null
            ? <String, ServerCredential>{}
            : Map<String, ServerCredential>.from(
                (json["credentials"] as Map<String, dynamic>).map(
                  (k, v) => MapEntry(
                    k,
                    ServerCredential.fromJson(v as Map<String, dynamic>),
                  ),
                ),
              ),
      );

  Map<String, dynamic> toJson() => {
        "endpoints": List<dynamic>.from(endpoints.map((x) => x.toJson())),
        "locations": locations.map((k, v) => MapEntry(k, v.toJson())),
        "credentials": credentials.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class ServerCredential {
  String accessToken;
  bool isJoined;
  String port;

  ServerCredential({
    required this.accessToken,
    required this.isJoined,
    required this.port,
  });

  factory ServerCredential.fromJson(Map<String, dynamic> json) =>
      ServerCredential(
        accessToken: json["access_token"] ?? '',
        isJoined: json["isJoined"] ?? false,
        port: json["port"]?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        "access_token": accessToken,
        "isJoined": isJoined,
        "port": port,
      };
}

class Endpoint {
  String type;
  String tag;
  String server;
  String serverPort;

  Endpoint({
    required this.type,
    required this.tag,
    required this.server,
    required this.serverPort,
  });

  factory Endpoint.fromJson(Map<String, dynamic> json) => Endpoint(
      type: json["type"],
      tag: json["tag"],
      server: json["server"] ?? '',
      serverPort:
          json["server_port"] == null ? "" : json["server_port"].toString());

  Map<String, dynamic> toJson() => {
        "type": type,
        "tag": tag,
        "server": server,
        "server_port": serverPort,
      };
}

class Location_ {
  String country;
  String countryCode;
  String city;
  double latitude;
  double longitude;

  // tag will be assigned later, not in the JSON
  // it will map to the endpoint tag
  String tag;

  // As have default value, we can derive protocol from tag
  String protocol = '';

  Location_({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.tag,
  });

  factory Location_.fromJson(Map<String, dynamic> json) => Location_(
        country: json["country"] ?? '',
        countryCode: json["country_code"] ?? '',
        city: json["city"] ?? '',
        latitude: json["latitude"]?.toDouble() ?? 0.0,
        longitude: json["longitude"]?.toDouble() ?? 0.0,
        tag: "",
      );

  Location_ copyWith({
    String? country,
    String? countryCode,
    String? city,
    double? latitude,
    double? longitude,
    String? tag,
    String? protocol,
  }) {
    return Location_(
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tag: tag ?? this.tag,
    )..protocol = protocol ?? this.protocol;
  }

  Map<String, dynamic> toJson() => {
        "country": country,
        "city": city,
        "latitude": latitude,
        "longitude": longitude,
        "country_code": countryCode,
      };
}

class Server {
  String group;
  String tag;
  String type;
  Endpoint? options;
  Location_? location;

  Server({
    required this.group,
    required this.tag,
    required this.type,
    required this.options,
    required this.location,
  });

  factory Server.fromJson(Map<String, dynamic> json) => Server(
        group: json["Group"],
        tag: json["Tag"],
        type: json["Type"],
        options: Endpoint.fromJson(json["Options"]),
        location: Location_.fromJson(json["Location"]),
      );

  Map<String, dynamic> toJson() => {
        "Group": group,
        "Tag": tag,
        "Type": type,
        "Options": options?.toJson(),
        "Location": location?.toJson(),
      };
}
