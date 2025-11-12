import 'package:flutter/services.dart';
import 'package:lantern/core/models/entity/app_data.dart';

enum AppDataEventType { snapshot, delta, iconReady, unknown }

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
      'iconReady' => AppDataEventType.iconReady,
      _ => AppDataEventType.unknown,
    };
    final rawItems = (e['items'] as List?) ?? const [];
    final items = rawItems.map((m) => AppData.fromMap(m as Map)).toList();
    final removedTop =
        (e['removed'] as List?)?.cast<String>() ?? const <String>[];
    final removedFromItems =
        items.where((i) => i.removed).map((i) => i.bundleId);

    return AppDataEvent(
      type: type,
      items: items.where((i) => !i.removed).toList(),
      removed: <String>{...removedTop, ...removedFromItems}
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}
