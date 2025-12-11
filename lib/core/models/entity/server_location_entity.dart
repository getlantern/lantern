import 'package:lantern/core/common/common.dart';
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
  final AutoLocationEntity autoLocation;

  ServerLocationEntity({
    required this.autoSelect,
    required this.countryCode,
    required this.country,
    required this.city,
    required this.displayName,
    required this.serverName,
    required this.serverType,
    AutoLocationEntity? autoLocation,
  }) : autoLocation = autoLocation ??
            AutoLocationEntity(
              serverLocation: 'fastest_server'.i18n,
              serverName: '',
            );
}

@Entity()
class AutoLocationEntity {
  @Id()
  int id = 0;
  final String serverLocation;
  final String serverName;

  AutoLocationEntity({
    required this.serverLocation,
    required this.serverName,
  });
}
