import 'dart:convert';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/utils/country_utils.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class ServerLocationEntity {
  @Id(assignable: false)
  int id = 0;

  final bool autoSelect;
  final String serverName;
  final String serverType;
  final String countryCode;
  final String country;
  final String city;
  final String displayName;

  /// DB field storing the nested object as JSON
  String autoLocationJson;

  /// Transient (non-persisted) convenience getter/setter
  @Transient()
  AutoLocationEntity? get autoLocation {
    if (autoLocationJson.isEmpty) return null;
    try {
      final map = jsonDecode(autoLocationJson) as Map<String, dynamic>;
      return AutoLocationEntity.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @Transient()
  set autoLocation(AutoLocationEntity? v) {
    if (v == null) {
      autoLocationJson = '';
    } else {
      autoLocationJson = jsonEncode(v.toJson());
    }
  }

  ServerLocationEntity({
    required this.autoSelect,
    required this.serverName,
    required this.serverType,
    String? countryCode,
    String? country,
    String? city,
    String? displayName,
    AutoLocationEntity? autoLocationParam,
  })  : country = country ?? '',
        city = city ?? '',
        countryCode = countryCode ?? '',
        displayName = displayName ?? _buildDisplayName(country, city),
        autoLocationJson = '' {
    autoLocation = autoLocationParam;
  }

  static String _buildDisplayName(String? country, String? city) {
    final c = country?.trim() ?? '';
    final t = city?.trim() ?? '';

    if (c.isEmpty && t.isEmpty) return '';
    if (c.isEmpty) return t;
    if (t.isEmpty) return c;
    return '$c - $t';
  }

  ServerLocationEntity lanternLocation({
    required Location_ server,
    bool autoSelect = false,
  }) {
    return ServerLocationEntity(
      autoSelect: autoSelect,
      serverName: server.tag,
      serverType: ServerLocationType.lanternLocation.name,
      country: server.country,
      city: server.city,
      displayName: '${server.country} - ${server.city}',
      countryCode: CountryUtils.getCountryCode(server.country),
      autoLocationParam: autoLocation,
    );
  }

  ServerLocationEntity privateServer({
    required PrivateServerEntity privateServer,
    bool autoSelect = false,
  }) {
    return ServerLocationEntity(
      autoSelect: autoSelect,
      serverName: privateServer.serverName,
      serverType: ServerLocationType.privateServer.name,
      countryCode: privateServer.serverCountryCode,
      country: '',
      city: privateServer.serverLocationName,
      displayName: privateServer.serverLocationName,
    );
  }
}

class AutoLocationEntity {
  final String country;
  final String countryCode;
  final String displayName;

  AutoLocationEntity({
    required this.country,
    required this.countryCode,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
        'country': country,
        'countryCode': countryCode,
        'displayName': displayName,
      };

  factory AutoLocationEntity.fromJson(Map<String, dynamic> json) {
    return AutoLocationEntity(
      country: (json['country'] ?? '') as String,
      countryCode: (json['countryCode'] ?? '') as String,
      displayName: (json['displayName'] ?? '') as String,
    );
  }
}
