import 'package:objectbox/objectbox.dart';

@Entity()
class ServerLocationEntity {
  @Id(assignable: false)
  int id = 0;
  final bool autoSelect;
  final String serverLocation;
  final String serverName;
  final String serverType;

  ServerLocationEntity({
    required this.autoSelect,
    required this.serverLocation,
    required this.serverName,
    required this.serverType,
  });
}
