import 'package:lantern/core/services/local_storage.dart';

/// Cached view of user enabled apps split-tunneling selection
class EnabledAppsSnapshot {
  EnabledAppsSnapshot({
    required this.keys,
    required this.names,
  });

  final Set<String> keys;
  final Set<String> names;

  bool contains({required String key, required String name}) {
    return keys.contains(key) || names.contains(name);
  }
}

/// EnabledApps is a helper for reading enabled apps state from LocalStorage
/// in a consistent way
class EnabledApps {
  EnabledApps(this._db);
  final LocalStorageService _db;

  EnabledAppsSnapshot snapshot() {
    return EnabledAppsSnapshot(
      keys: getEnabledAppKeys(),
      names: getEnabledAppNames(),
    );
  }

  Set<String> getEnabledAppKeys() {
    final savedApps = _db.getAllApps();

    String keyForSavedApp(dynamic app) {
      final String? bundleId = (app.bundleId as String?)?.trim();
      if (bundleId != null && bundleId.isNotEmpty) return bundleId;
      return (app.name as String).trim();
    }

    return savedApps.where((app) => app.isEnabled).map(keyForSavedApp).toSet();
  }

  Set<String> getEnabledAppNames() {
    final saved = _db.getAllApps();
    return saved
        .where((a) => a.isEnabled)
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
  }
}
