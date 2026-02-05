import 'package:lantern/core/models/app_data.dart';

enum AppDataEventType { snapshot, delta, iconReady, unknown }

extension AppDataEventTypeX on AppDataEventType {
  String get key => switch (this) {
        AppDataEventType.snapshot => 'snapshot',
        AppDataEventType.delta => 'delta',
        AppDataEventType.iconReady => 'icon_ready',
        AppDataEventType.unknown => 'unknown',
      };

  static AppDataEventType fromRaw(Object? raw) {
    final s = (raw ?? '').toString();
    return switch (s) {
      'snapshot' => AppDataEventType.snapshot,
      'delta' => AppDataEventType.delta,
      'icon_ready' => AppDataEventType.iconReady,
      'iconReady' => AppDataEventType.iconReady,
      _ => AppDataEventType.unknown,
    };
  }
}

class AppDataEvent {
  final AppDataEventType type;
  final List<AppData> items;

  /// Bundle IDs to remove from the cache
  final List<String> removed;

  const AppDataEvent({
    required this.type,
    required this.items,
    required this.removed,
  });

  factory AppDataEvent.fromMap(Map<dynamic, dynamic> event) {
    final e = Map<String, dynamic>.from(event);

    final type = AppDataEventTypeX.fromRaw(e['type']);

    final rawItems = (e['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((m) => AppData.fromMap(m))
        .toList(growable: false);

    // We may get removals either via a top-level `removed` list,
    // or by individual items marked as removed
    final removedTop = (e['removed'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final removedFromItems =
        items.where((i) => i.removed).map((i) => i.bundleId);

    final removed = <String>{...removedTop, ...removedFromItems}
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    // Only keep items that aren't marked removed
    final keptItems = items.where((i) => !i.removed).toList(growable: false);

    return AppDataEvent(
      type: type,
      items: keptItems,
      removed: removed,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.key,
        'items': items.map((a) => a.toJson()).toList(),
        'removed': removed,
      };

  @override
  String toString() =>
      'AppDataEvent(type: $type, items: ${items.length}, removed: ${removed.length})';
}
