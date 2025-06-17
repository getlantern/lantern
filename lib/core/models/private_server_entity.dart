import 'package:objectbox/objectbox.dart';

@Entity()
class PrivateServerEntity {
  @Id(assignable: false)
  int id = 0;
  final String serverName;
  final String externalIp;
  final String port;
  final String accessToken;

  PrivateServerEntity({
    required this.serverName,
    required this.externalIp,
    required this.port,
    required this.accessToken,
  });


  PrivateServerEntity copyWith({
    String? serverName,
    String? externalIp,
    String? port,
    String? accessToken,
  }) {
    return PrivateServerEntity(
      serverName: serverName ?? this.serverName,
      externalIp: externalIp ?? this.externalIp,
      port: port ?? this.port,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
