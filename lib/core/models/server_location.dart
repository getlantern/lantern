import 'dart:convert';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/core/utils/helper_tags.dart';

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

  /// The Smart Location for the server auto-selection picked. A helper
  /// outbound is a friend's device, so where it is is never shown: it gets the
  /// generic label used when no location is known.
  factory ServerLocation.autoSelected(Server server) {
    if (isHelperTag(server.tag)) {
      return ServerLocation(
        serverType: ServerLocationType.auto.name,
        serverName: '',
        displayName: '',
        autoLocation: AutoLocation(
          country: '',
          countryCode: '',
          displayName: 'fastest_server'.i18n,
          tag: server.tag,
        ),
      );
    }
    final country = server.location.country;
    final city = server.location.city;
    return ServerLocation(
      serverType: ServerLocationType.auto.name,
      serverName: '',
      displayName: '',
      city: city,
      autoLocation: AutoLocation(
        countryCode: server.location.countryCode,
        country: country,
        displayName: '$country - $city',
        tag: server.tag,
      ),
    );
  }

  /// Build from a radiance [Server] object.
  factory ServerLocation.fromServer({
    required Server server,
    ServerLocationType type = ServerLocationType.lanternLocation,
    AutoLocation? autoLocation,
  }) {
    return ServerLocation(
      serverName: server.tag,
      serverType: type.name,
      country: server.location.country,
      city: server.location.city,
      countryCode: server.location.countryCode,
      displayName: '${server.location.country} - ${server.location.city}',
      protocol: server.type,
      autoLocation: autoLocation,
    );
  }

  /// The user's personal proxies, selected as one location, or with
  /// [friendTag] the one friend whose outbound tag it is. Where the friends
  /// are is never shown. Nor is a friend's name kept here, where it would be
  /// stored and sent to the home-screen widget: the UI looks it up by
  /// [personalProxyFriendTag].
  factory ServerLocation.personalProxy({String? friendTag}) => ServerLocation(
    serverName: friendTag == null
        ? personalProxiesTag
        : personalProxySelection(friendTag),
    serverType: ServerLocationType.personalProxy.name,
    displayName: 'personal_proxy'.i18n,
  );

  /// The outbound tag of the friend selected on their own, or null for the
  /// personal proxies group and every other location.
  String? get personalProxyFriendTag =>
      serverType == ServerLocationType.personalProxy.name
      ? personalProxyFriend(serverName)
      : null;

  /// The location of the server radiance reports as selected.
  factory ServerLocation.selected(Server server) {
    if (server.tag == personalProxiesTag) return ServerLocation.personalProxy();
    final friend = personalProxyFriend(server.tag);
    if (friend != null) return ServerLocation.personalProxy(friendTag: friend);
    return ServerLocation.fromServer(server: server).copyWith(
      serverType: server.isLantern
          ? ServerLocationType.lanternLocation.name
          : ServerLocationType.privateServer.name,
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

  /// [toJson] for log lines. A personal proxy's label would reveal it in any
  /// language, so it is left out.
  Map<String, dynamic> toLogJson() {
    final json = toJson();
    if (serverType == ServerLocationType.personalProxy.name) {
      json.remove('displayName');
    }
    return json;
  }

  factory ServerLocation.fromJson(Map<String, dynamic> json) {
    final autoLocation = json['autoLocation'] is Map<String, dynamic>
        ? AutoLocation.fromJson(json['autoLocation'] as Map<String, dynamic>)
        : null;
    // Rebuilt rather than read, so the label follows the current language.
    if (json['serverType'] == ServerLocationType.personalProxy.name) {
      final name = json['serverName'];
      return ServerLocation.personalProxy(
        friendTag: name is String ? personalProxyFriend(name) : null,
      ).copyWith(autoLocation: autoLocation);
    }
    return ServerLocation(
      serverName: (json['serverName'] ?? '') as String,
      serverType: (json['serverType'] ?? '') as String,
      countryCode: (json['countryCode'] ?? '') as String,
      country: (json['country'] ?? '') as String,
      city: (json['city'] ?? '') as String,
      displayName: (json['displayName'] as String?),
      protocol: (json['protocol'] ?? '') as String,
      autoLocation: autoLocation,
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

  String get protocol => tag != null && tag!.isNotEmpty && !isHelperTag(tag!)
      ? tag!.split('-').first
      : '';

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
