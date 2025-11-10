import 'package:flutter/services.dart';

enum AppDataEventType { snapshot, delta, iconReady, unknown }

class AppData {
  final String pkg;
  final String name;
  final String iconPath;
  final String appPath;
  final int lastUpdateTime;
  final bool removed;
  final Uint8List? iconBytes;
  final bool isEnabled;

  const AppData({
    required this.pkg,
    required this.name,
    required this.iconPath,
    required this.appPath,
    required this.lastUpdateTime,
    required this.removed,
    this.isEnabled = false,
    this.iconBytes,
  });

  factory AppData.fromMap(Map<dynamic, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);
    final pkg = (m['package'] ?? m['bundleId'] ?? '') as String;
    final name = (m['label'] ?? m['name'] ?? pkg).toString();
    return AppData(
      pkg: pkg,
      name: name,
      iconPath: (m['iconPath'] as String?) ?? '',
      appPath: (m['appPath'] as String?) ?? '',
      lastUpdateTime: (m['lastUpdateTime'] as num?)?.toInt() ?? 0,
      removed: m['removed'] == true || m['isRemoved'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'package': pkg,
        'bundleId': pkg,
        'label': name,
        'name': name,
        'iconPath': iconPath,
        'appPath': appPath,
        'lastUpdateTime': lastUpdateTime,
        'removed': removed,
      };

  String cacheKey(int sizePx, int dpi) => '$pkg@$lastUpdateTime@$sizePx@$dpi';
}

class AppDataEvent {
  final AppDataEventType type;
  final List<AppData> items;
  final List<String> removed;

  AppDataEvent({
    required this.type,
    required this.items,
    required this.removed,
  });

  factory AppDataEvent.fromMap(Map<dynamic, dynamic> event) {
    final e = Map<String, dynamic>.from(event);
    final type = switch ((e['type'] ?? '').toString()) {
      'snapshot' => AppDataEventType.snapshot,
      'delta' => AppDataEventType.delta,
      'icon_ready' => AppDataEventType.iconReady,
      _ => AppDataEventType.unknown,
    };
    final rawItems = (e['items'] as List?) ?? const [];
    final items = rawItems.map((m) => AppData.fromMap(m as Map)).toList();
    final removedTop =
        (e['removed'] as List?)?.cast<String>() ?? const <String>[];
    final removedFromItems = items.where((i) => i.removed).map((i) => i.pkg);

    return AppDataEvent(
      type: type,
      items: items.where((i) => !i.removed).toList(),
      removed: <String>{...removedTop, ...removedFromItems}
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}
