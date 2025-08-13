class AvailableServers {
  Lantern lantern;

  AvailableServers({
    required this.lantern,
  });

  factory AvailableServers.fromJson(Map<String, dynamic> json) =>
      AvailableServers(lantern: Lantern.fromJson(json["lantern"]));

  Map<String, dynamic> toJson() => {"lantern": lantern.toJson()};
}

class Lantern {
  List<Endpoint> endpoints;
  Map<String, Location_> locations;

  Lantern({
    required this.endpoints,
    required this.locations,
  });

  factory Lantern.fromJson(Map<String, dynamic> json) => Lantern(
        endpoints: List<Endpoint>.from(
            json["endpoints"].map((x) => Endpoint.fromJson(x))),
        locations: (Map<String, Location_>.from(json["locations"]
            .map((k, v) => MapEntry(k, Location_.fromJson(v))))),
      );

  Map<String, dynamic> toJson() => {
        "endpoints": List<dynamic>.from(endpoints.map((x) => x.toJson())),
        "locations": locations.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class Endpoint {
  String type;
  String tag;

  Endpoint({
    required this.type,
    required this.tag,
  });

  factory Endpoint.fromJson(Map<String, dynamic> json) => Endpoint(
        type: json["type"],
        tag: json["tag"],
      );

  Map<String, dynamic> toJson() => {
        "type": type,
        "tag": tag,
      };
}

class Location_ {
  String country;
  String city;
  double latitude;
  double longitude;

  Location_({
    required this.country,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  factory Location_.fromJson(Map<String, dynamic> json) => Location_(
        country: json["country"],
        city: json["city"],
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "country": country,
        "city": city,
        "latitude": latitude,
        "longitude": longitude,
      };
}
