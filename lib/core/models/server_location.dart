class ServerLocation {
  final String locationName;
  final String countryCode;

  const ServerLocation({
    required this.locationName,
    required this.countryCode,
  });

  factory ServerLocation.fromJson(Map<String, dynamic> json) => ServerLocation(
        locationName:
            json['location_name'] ?? json['locationName'] ?? json['name'] ?? '',
        countryCode:
            (json['country_code'] ?? json['countryCode'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'location_name': locationName,
        'country_code': countryCode,
      };
}
