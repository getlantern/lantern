import 'dart:typed_data';

import 'package:lantern/core/utils/app_data_utils.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class AppData {
  int id;
  String name;
  String bundleId;
  Uint8List? iconBytes;
  String iconPath;
  String appPath;
  bool isEnabled;
  final int lastUpdateTime;
  final bool removed;

  AppData({
    this.id = 0,
    required this.name,
    required this.bundleId,
    this.iconBytes,
    this.iconPath = '',
    this.appPath = '',
    this.isEnabled = false,
    this.lastUpdateTime = 0,
    this.removed = false,
  });

  AppData copyWith({
    int? id,
    String? name,
    String? bundleId,
    String? iconPath,
    Uint8List? iconBytes,
    String? appPath,
    bool? isEnabled,
    int? lastUpdateTime,
    bool? removed,
  }) {
    return AppData(
      id: id ?? this.id,
      name: name ?? this.name,
      bundleId: bundleId ?? this.bundleId,
      iconPath: iconPath ?? this.iconPath,
      iconBytes: iconBytes ?? this.iconBytes,
      appPath: appPath ?? this.appPath,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      removed: removed ?? this.removed,
    );
  }

  String cacheKey(int sizePx, int dpi) => '$bundleId@$sizePx@$dpi';

  factory AppData.fromMap(Map<dynamic, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    final bundleId = (m['package'] ?? m['bundleId'] ?? '') as String;
    final name = (m['label'] ?? m['name'] ?? bundleId).toString();

    return AppData(
      bundleId: bundleId,
      name: name,
      iconPath: (m['iconPath'] as String?) ?? '',
      appPath: (m['appPath'] as String?) ?? '',
      iconBytes: iconToBytes(m['icon'] ?? m['iconBytes']),
      lastUpdateTime: (m['lastUpdateTime'] as num?)?.toInt() ?? 0,
      removed: m['removed'] == true || m['isRemoved'] == true,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      name: (json['name'] ?? '').toString(),
      bundleId: (json['bundleId'] ?? json['package'] ?? '').toString(),
      iconPath: (json['iconPath'] ?? '').toString(),
      appPath: (json['appPath'] ?? '').toString(),
      isEnabled: json['isEnabled'] == true,
      iconBytes: iconToBytes(json['icon'] ?? json['iconBytes']),
      lastUpdateTime: (json['lastUpdateTime'] as num?)?.toInt() ?? 0,
      removed: json['removed'] == true || json['isRemoved'] == true,
    );
  }
}
