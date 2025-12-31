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

  // factory PrivateServerEntity.withLocation({
  //   required String serverName,
  //   required String externalIp,
  //   required String port,
  //   required String accessToken,
  //   required ServerLocation serverLocation,
  //   bool isJoined = false,
  //   bool userSelected = false,
  // }) {
  //   return PrivateServerEntity(
  //     serverName: serverName,
  //     externalIp: externalIp,
  //     port: port,
  //     accessToken: accessToken,
  //     serverLocationName: serverLocation.locationName,
  //     serverCountryCode: serverLocation.countryCode,
  //     isJoined: isJoined,
  //     userSelected: userSelected,
  //   );
  // }

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
    return PrivateServerEntity(
      serverName: e['tag'],
      externalIp: e['external_ip'],
      port: e['port'].toString(),
      accessToken: e['access_token'],
      serverLocationName: e['location'],
      serverCountryCode: (e['location'].toString().countryCode) ?? '',
      protocol: e['protocol'] ?? '',
    );

    // if (locRaw is String) {
    //   locationName = locRaw.toString();
    //   //extract country code if possible
    //   countryCode = locationName.countryCode;
    // } else {
    //   // try explicit fields
    //   locationName = (e['location_name'] ?? e['locationName'] ?? '').toString();
    //   countryCode = (e['country_code'] ?? e['countryCode'] ?? '').toString();
    // }
    //
    // return PrivateServerEntity.withLocation(
    //   serverName:
    //       (e['tag'] ?? e['server_name'] ?? e['serverName'] ?? '').toString(),
    //   externalIp: (e['external_ip'] ?? e['externalIp'] ?? '').toString(),
    //   port: (e['port'] ?? '').toString(),
    //   accessToken: (e['access_token'] ?? e['accessToken'] ?? '').toString(),
    //   serverLocation: ServerLocation(
    //     locationName: locationName,
    //     countryCode: countryCode,
    //   ),
    //   isJoined: (e['is_joined'] ?? e['isJoined'] ?? false) == true,
    //   userSelected: (e['user_selected'] ?? e['userSelected'] ?? false) == true,
    // );
  }

// ServerLocation get serverLocation => ServerLocation(
//       locationName: serverLocation.locationName,
//       countryCode: serverLocation.locationName,
//     );
}
