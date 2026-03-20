import 'package:lantern/core/common/common.dart';

class PrivateServer {
  final String serverName;
  final String externalIp;
  final String port;
  final String accessToken;
  final String serverLocationName;
  final String serverCountryCode;
  final String protocol;

  final bool isJoined;
  final bool userSelected;

  const PrivateServer({
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

  PrivateServer copyWith({
    String? serverName,
    String? externalIp,
    String? port,
    String? accessToken,
    String? serverLocationName,
    String? serverCountryCode,
    String? protocol,
    bool? isJoined,
    bool? userSelected,
  }) {
    return PrivateServer(
      serverName: serverName ?? this.serverName,
      externalIp: externalIp ?? this.externalIp,
      port: port ?? this.port,
      accessToken: accessToken ?? this.accessToken,
      serverLocationName: serverLocationName ?? this.serverLocationName,
      serverCountryCode: serverCountryCode ?? this.serverCountryCode,
      protocol: protocol ?? this.protocol,
      isJoined: isJoined ?? this.isJoined,
      userSelected: userSelected ?? this.userSelected,
    );
  }

  /// Serialized form used by the backend/FFI layer
  Map<String, dynamic> toJson() => {
        'tag': serverName,
        'external_ip': externalIp,
        'port': port,
        'access_token': accessToken,
        'location': serverLocationName,
        'location_name': serverLocationName,
        'country_code': serverCountryCode,
        'protocol': protocol,
        'is_joined': isJoined,
        'user_selected': userSelected,
      };

  static PrivateServer fromJson(Map<String, dynamic> e) {
    try {
      var countryCode = '';

      try {
        if (e.containsKey('location')) {
          countryCode = e['location'].toString().countryCode;
        } else if (e.containsKey('country_code')) {
          countryCode = (e['country_code'] ?? '').toString();
        }
      } catch (err) {
        appLogger.error('Error extracting country code: $err');
      }

      return PrivateServer(
        serverName: (e['tag'] ?? '').toString(),
        externalIp: (e['external_ip'] ?? '').toString(),
        port: (e['port'] ?? '').toString(),
        accessToken: (e['access_token'] ?? '').toString(),
        serverLocationName: (e['location'] ?? '').toString(),
        serverCountryCode: countryCode,
        protocol: (e['protocol'] ?? '').toString(),
        isJoined: (e['is_joined'] ?? false) == true,
        userSelected: (e['user_selected'] ?? false) == true,
      );
    } catch (err) {
      appLogger.error('PrivateServer fromJson error: $err');
      rethrow;
    }
  }
}
