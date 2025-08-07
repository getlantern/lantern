import 'package:objectbox/objectbox.dart';

@Entity()
class PrivateServerEntity {
  @Id(assignable: false)
  int id = 0;
  final String serverName;
  final String externalIp;
  final String port;
  final String accessToken;
  final String serverLocation;
  bool isJoined;
  bool userSelected;

  PrivateServerEntity({
    required this.serverName,
    required this.externalIp,
    required this.port,
    required this.accessToken,
    required this.serverLocation,
    this.isJoined = false,
    this.userSelected = false,
  });

  PrivateServerEntity copyWith({
    String? serverName,
    String? externalIp,
    String? port,
    String? accessToken,
    String? countryCode,
    bool? isJoined,
    bool? userSelected,
  }) {
    return PrivateServerEntity(
      serverName: serverName ?? this.serverName,
      externalIp: externalIp ?? this.externalIp,
      port: port ?? this.port,
      accessToken: accessToken ?? this.accessToken,
      serverLocation: countryCode ?? serverLocation,
      isJoined: isJoined ?? this.isJoined,
      userSelected: userSelected ?? this.userSelected,
    );
  }

  static PrivateServerEntity fromJson(Map<String, dynamic> e) {
    return PrivateServerEntity(
        serverName: e['tag'],
        externalIp: e['external_ip'],
        port: e['port'].toString(),
        accessToken: e['access_token'],
        serverLocation: e['location'] ?? '');
  }
}
