class AppData {
  final String name;
  final String bundleId;
  final String iconPath;
  final String appPath;
  final bool isEnabled;

  AppData({
    required this.name,
    required this.bundleId,
    required this.iconPath,
    required this.appPath,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "bundleId": bundleId,
        "iconPath": iconPath,
        "appPath": appPath,
        "isEnabled": isEnabled,
      };

  AppData copyWith({
    String? name,
    String? bundleId,
    String? iconPath,
    String? appPath,
    bool? isEnabled,
  }) {
    return AppData(
      name: name ?? this.name,
      isEnabled: isEnabled ?? false,
      bundleId: bundleId ?? this.bundleId,
      iconPath: iconPath ?? this.iconPath,
      appPath: appPath ?? this.appPath,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: json["name"],
      bundleId: json["bundleId"],
      iconPath: json["iconPath"],
      appPath: json["appPath"],
      isEnabled: json["isEnabled"] ?? false,
    );
  }
}
