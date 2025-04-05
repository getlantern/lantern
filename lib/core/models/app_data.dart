import 'package:objectbox/objectbox.dart';

@Entity()
class AppData {
  int id;
  String name;
  String bundleId;
  String iconPath;
  String appPath;
  bool isEnabled;

  AppData({
    this.id = 0,
    required this.name,
    required this.bundleId,
    required this.iconPath,
    required this.appPath,
    required this.isEnabled,
  });

  AppData copyWith({
    int? id,
    String? name,
    String? bundleId,
    String? iconPath,
    String? appPath,
    bool? isEnabled,
  }) {
    return AppData(
      id: id ?? this.id,
      name: name ?? this.name,
      bundleId: bundleId ?? this.bundleId,
      iconPath: iconPath ?? this.iconPath,
      appPath: appPath ?? this.appPath,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: json['name'] ?? '',
      bundleId: json['bundleId'] ?? '',
      iconPath: json['iconPath'] ?? '',
      appPath: json['appPath'] ?? '',
      isEnabled: json['isEnabled'] ?? false,
    );
  }
}
