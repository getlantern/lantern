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
        endpoints: json["endpoints"] == null
            ? []
            : List<Endpoint>.from(
                json["endpoints"].map((x) => Endpoint.fromJson(x))),
        locations: (Map<String, Location_>.from(json["locations"].map(
          (k, v) => MapEntry(k, Location_.fromJson(v)..tag = k),
        ))),
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
  String countryCode;
  String city;
  double latitude;
  double longitude;

  //tag will be assigned later, not in the JSON
  // it will map to the endpoint tag
  String tag;

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
