import 'package:lantern/core/models/server_location.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class PrivateServerEntity {
  @Id(assignable: false)
  int id = 0;
  final String serverName;
  final String externalIp;
  final String port;
  final String accessToken;
  final String serverLocationName;
  final String serverCountryCode;
  bool isJoined;
  bool userSelected;

  PrivateServerEntity({
    required this.serverName,
    required this.externalIp,
    required this.port,
    required this.accessToken,
    required this.serverLocationName,
    required this.serverCountryCode,
    this.isJoined = false,
    this.userSelected = false,
  });

  PrivateServerEntity copyWith({
    String? serverName,
    String? externalIp,
    String? port,
    String? accessToken,
    String? serverLocationName,
    String? serverCountryCode,
    ServerLocation? serverLocation,
    bool? isJoined,
    bool? userSelected,
  }) {
    return PrivateServerEntity(
      serverName: serverName ?? this.serverName,
      externalIp: externalIp ?? this.externalIp,
      port: port ?? this.port,
      accessToken: accessToken ?? this.accessToken,
      serverLocationName: serverLocation?.locationName ??
          serverLocationName ??
          this.serverLocationName,
      serverCountryCode: serverLocation?.countryCode ??
          serverCountryCode ??
          this.serverCountryCode,
      isJoined: isJoined ?? this.isJoined,
      userSelected: userSelected ?? this.userSelected,
    );
  }

  factory PrivateServerEntity.withLocation({
    required String serverName,
    required String externalIp,
    required String port,
    required String accessToken,
    required ServerLocation serverLocation,
    bool isJoined = false,
    bool userSelected = false,
  }) {
    return PrivateServerEntity(
      serverName: serverName,
      externalIp: externalIp,
      port: port,
      accessToken: accessToken,
      serverLocationName: serverLocation.locationName,
      serverCountryCode: serverLocation.countryCode,
      isJoined: isJoined,
      userSelected: userSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'tag': serverName,
        'external_ip': externalIp,
        'port': port,
        'access_token': accessToken,
        'location': serverLocationName,
        'location_name': serverLocationName,
        'country_code': serverCountryCode,
        'is_joined': isJoined,
        'user_selected': userSelected,
      };

  static PrivateServerEntity fromJson(Map<String, dynamic> e) {
    final dynamic locRaw = e['location'] ?? e['server_location'];
    String locName = '';
    String locCC = '';

    if (locRaw is Map<String, dynamic>) {
      final sl = ServerLocation.fromJson(locRaw);
      locName = sl.locationName;
      locCC = sl.countryCode;
    } else if (locRaw is String) {
      locName = locRaw;
      locCC = (e['country_code'] ?? e['countryCode'] ?? '').toString();
    } else {
      // try explicit fields
      locName = (e['location_name'] ?? e['locationName'] ?? '').toString();
      locCC = (e['country_code'] ?? e['countryCode'] ?? '').toString();
    }

    return PrivateServerEntity(
      serverName:
          (e['tag'] ?? e['server_name'] ?? e['serverName'] ?? '').toString(),
      externalIp: (e['external_ip'] ?? e['externalIp'] ?? '').toString(),
      port: (e['port'] ?? '').toString(),
      accessToken: (e['access_token'] ?? e['accessToken'] ?? '').toString(),
      serverLocationName: locName,
      serverCountryCode: locCC,
      isJoined: (e['is_joined'] ?? e['isJoined'] ?? false) == true,
      userSelected: (e['user_selected'] ?? e['userSelected'] ?? false) == true,
    );
  }

  ServerLocation get serverLocation => ServerLocation(
        locationName: serverLocationName,
        countryCode: serverCountryCode,
      );
}
