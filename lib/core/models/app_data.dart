import 'dart:typed_data';

import 'package:lantern/core/utils/app_data_utils.dart';

class AppData {
  final String name;
  final String bundleId;
  final Uint8List? iconBytes;
  final String iconPath;
  final String appPath;
  final bool isEnabled;
  final int lastUpdateTime;
  final bool removed;

  /// True when the app registers itself as an http(s) handler (a browser).
  /// Populated on Android (intent handlers), macOS (LaunchServices) and
  /// Windows (registry default-app scan); defaults to false elsewhere.
  final bool isBrowser;

  /// macOS only: inner bundle name (`<App>.app/Wrapper/<this>`) for iPhone
  /// and iPad apps; split tunneling matches on it instead of [appPath].
  final String wrappedBundle;

  const AppData({
    required this.name,
    required this.bundleId,
    this.iconBytes,
    this.iconPath = '',
    this.appPath = '',
    this.isEnabled = false,
    this.lastUpdateTime = 0,
    this.removed = false,
    this.isBrowser = false,
    this.wrappedBundle = '',
  });

  AppData copyWith({
    String? name,
    String? bundleId,
    String? iconPath,
    Uint8List? iconBytes,
    String? appPath,
    bool? isEnabled,
    int? lastUpdateTime,
    bool? removed,
    bool? isBrowser,
    String? wrappedBundle,
  }) {
    return AppData(
      name: name ?? this.name,
      bundleId: bundleId ?? this.bundleId,
      iconPath: iconPath ?? this.iconPath,
      iconBytes: iconBytes ?? this.iconBytes,
      appPath: appPath ?? this.appPath,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      removed: removed ?? this.removed,
      isBrowser: isBrowser ?? this.isBrowser,
      wrappedBundle: wrappedBundle ?? this.wrappedBundle,
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
      isBrowser: m['isBrowser'] == true,
      wrappedBundle: (m['wrappedBundle'] as String?) ?? '',
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        name: (json['name'] ?? '').toString(),
        bundleId: (json['bundleId'] ?? json['package'] ?? '').toString(),
        iconPath: (json['iconPath'] ?? '').toString(),
        appPath: (json['appPath'] ?? '').toString(),
        isEnabled: json['isEnabled'] == true,
        iconBytes: iconToBytes(json['icon'] ?? json['iconBytes']),
        lastUpdateTime: (json['lastUpdateTime'] as num?)?.toInt() ?? 0,
        removed: json['removed'] == true || json['isRemoved'] == true,
        isBrowser: json['isBrowser'] == true,
        wrappedBundle: (json['wrappedBundle'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'bundleId': bundleId,
        'iconPath': iconPath,
        'appPath': appPath,
        'isEnabled': isEnabled,
        'iconBytes': iconBytes, // or base64 if you serialize across FFI
        'lastUpdateTime': lastUpdateTime,
        'removed': removed,
        'isBrowser': isBrowser,
        'wrappedBundle': wrappedBundle,
      };
}
