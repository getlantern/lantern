class AppData {
  final String name;
  final String package;
  final String iconPath;
  final bool isEnabled;

  AppData({
    required this.name,
    required this.package,
    required this.iconPath,
    required this.isEnabled,
  });

  Map<String, dynamic> toJson() => {
        "name": name,
        "package": package,
        "iconPath": iconPath,
        "isEnabled": isEnabled,
      };

  AppData copyWith({
    String? name,
    String? package,
    String? iconUrl,
    bool? isEnabled,
  }) {
    return AppData(
      name: name ?? this.name,
      package: package ?? this.package,
      iconPath: iconUrl ?? this.iconPath,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: json["name"],
      package: json["package"],
      iconPath: json["iconPath"],
      isEnabled: json["isEnabled"] ?? false,
    );
  }
}
