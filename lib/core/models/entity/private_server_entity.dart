import 'package:lantern/core/common/common.dart';
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
  final String protocol;

  bool isJoined;
  bool userSelected;

  PrivateServerEntity({
    required this.serverName,
    required this.externalIp,
    required this.port,
    required this.accessToken,
    required this.serverLocationName,
    required this.serverCountryCode,
    required this.protocol,
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
    bool? isJoined,
    bool? userSelected,
    String? protocol,
  }) {
    return PrivateServerEntity(
        serverName: serverName ?? this.serverName,
        externalIp: externalIp ?? this.externalIp,
        port: port ?? this.port,
        accessToken: accessToken ?? this.accessToken,
        serverLocationName: serverLocationName ?? this.serverLocationName,
        serverCountryCode: serverCountryCode ?? this.serverCountryCode,
        isJoined: isJoined ?? this.isJoined,
        userSelected: userSelected ?? this.userSelected,
        protocol: protocol ?? this.protocol);
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
    try {
      String countryCode = '';
      try {
        if (e.containsKey('location')) {
          countryCode = e['location'].toString().countryCode;
        }
      } catch (e) {
        appLogger.error('Error extracting country code: $e');
      }

      return PrivateServerEntity(
        serverName: e['tag'] ?? '',
        externalIp: e['external_ip'] ?? '',
        port: e['port'].toString(),
        accessToken: e['access_token'] ?? '',
        serverLocationName: e['location'] ?? '',
        serverCountryCode: countryCode,
        protocol: e['protocol'] ?? '',
      );
    } catch (e) {
      appLogger.error('PrivateServerEntity fromJson error: $e');
      rethrow;
    }
  }
}
