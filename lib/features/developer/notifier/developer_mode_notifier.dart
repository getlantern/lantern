import 'dart:convert';

import 'package:lantern/core/models/developer_mode.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'developer_mode_notifier.g.dart';

@Riverpod(keepAlive: true)
class DeveloperModeNotifier extends _$DeveloperModeNotifier {
  static const _prefsKey = 'developer_mode_json';
  final _storage = LocalStorageService();

  @override
  DeveloperMode build() {
    _hydrate();
    return DeveloperMode.initial();
  }

  Future<void> _hydrate() async {
    final raw = await _storage.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = DeveloperMode.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
  }

  Future<void> updateDeveloperSettings(DeveloperMode dev) async {
    state = dev;
    await _storage.setString(_prefsKey, jsonEncode(dev.toJson()));
  }
}
