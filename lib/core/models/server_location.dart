import 'dart:convert';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/private_server.dart';

class ServerLocation {
  final String serverName;
  final String serverType;
  final String countryCode;
  final String country;
  final String city;
  final String displayName;
  final String protocol;

  /// Optional metadata for auto-selected locations.
  /// Kept as a nested model rather than flattening into this one
  final AutoLocation? autoLocation;

  ServerLocation({
    required this.serverName,
    required this.serverType,
    this.protocol = '',
    this.countryCode = '',
    this.country = '',
    this.city = '',
    String? displayName,
    this.autoLocation,
  }) : displayName = displayName ?? _buildDisplayName(country, city);

  static String _buildDisplayName(String country, String city) {
    final c = country.trim();
    final t = city.trim();

    if (c.isEmpty && t.isEmpty) return '';
    if (c.isEmpty) return t;
    if (t.isEmpty) return c;
    return '$c - $t';
  }

  /// Replaces `lanternLocation(...)` instance method
  factory ServerLocation.fromLanternLocation({
    required Location_ server,
    AutoLocation? autoLocation,
  }) {
    return ServerLocation(
      serverName: server.tag,
      serverType: ServerLocationType.lanternLocation.name,
      country: server.country,
      city: server.city,
      countryCode: server.countryCode,
      displayName: '${server.country} - ${server.city}',
      protocol: server.protocol,
      autoLocation: autoLocation,
    );
  }

  /// Build from a user private server (formerly `privateServer(...)`)
  factory ServerLocation.fromPrivateServer({
    required PrivateServer privateServer,
    AutoLocation? autoLocation,
  }) {
    return ServerLocation(
      serverName: privateServer.serverName,
      serverType: ServerLocationType.privateServer.name,
      countryCode: privateServer.serverCountryCode,
      country: '',
      city: privateServer.serverLocationName,
      displayName: privateServer.serverLocationName,
      protocol: privateServer.protocol,
      autoLocation: autoLocation,
    );
  }

  // ---------- JSON ----------
  Map<String, dynamic> toJson() => {
        'serverName': serverName,
        'serverType': serverType,
        'countryCode': countryCode,
        'country': country,
        'city': city,
        'displayName': displayName,
        'protocol': protocol,
        'autoLocation': autoLocation?.toJson(),
      };

  factory ServerLocation.fromJson(Map<String, dynamic> json) {
    return ServerLocation(
      serverName: (json['serverName'] ?? '') as String,
      serverType: (json['serverType'] ?? '') as String,
      countryCode: (json['countryCode'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      displayName: (json['displayName'] as String?),
      protocol: (json['protocol'] ?? '') as String,
      autoLocation: json['autoLocation'] is Map<String, dynamic>
          ? AutoLocation.fromJson(json['autoLocation'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ServerLocation.fromJsonString(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    return ServerLocation.fromJson(map);
  }

  ServerLocation copyWith({
    String? serverName,
    String? serverType,
    String? countryCode,
    String? country,
    String? city,
    String? displayName,
    String? protocol,
    AutoLocation? autoLocation,
  }) {
    return ServerLocation(
      serverName: serverName ?? this.serverName,
      serverType: serverType ?? this.serverType,
      countryCode: countryCode ?? this.countryCode,
      country: country ?? this.country,
      city: city ?? this.city,
      displayName: displayName ?? this.displayName,
      protocol: protocol ?? this.protocol,
      autoLocation: autoLocation ?? this.autoLocation,
    );
  }
}

class AutoLocation {
  final String country;
  final String countryCode;
  final String displayName;
  final String? tag;

  const AutoLocation({
    required this.country,
    required this.countryCode,
    required this.displayName,
    this.tag,
  });

  String get protocol =>
      tag != null && tag!.isNotEmpty ? tag!.split('-').first : '';

  Map<String, dynamic> toJson() => {
        'country': country,
        'countryCode': countryCode,
        'displayName': displayName,
        'tag': tag,
      };

  factory AutoLocation.fromJson(Map<String, dynamic> json) {
    return AutoLocation(
      country: (json['country'] ?? '') as String,
      countryCode: (json['countryCode'] ?? '') as String,
      displayName: (json['displayName'] ?? '') as String,
      tag: (json['tag'] as String?)?.isEmpty == true
          ? null
          : json['tag'] as String?,
    );
  }
}
