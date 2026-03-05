import 'package:lantern/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A wrapper around [SharedPreferencesWithCache].

/// All getters are **synchronous** (reads come from the in-memory cache).
/// All setters are **async** (write through to platform storage and update
/// the cache).
class LocalStorageService {
  late SharedPreferencesWithCache _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions());
  }

  // ── String ──────────────────────────────────────────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setString($key) failed', e, st);
    }
  }

  // ── Bool ─────────────────────────────────────────────────────────────────

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, bool value) async {
    try {
      await _prefs.setBool(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setBool($key) failed', e, st);
    }
  }

  // ── Int ──────────────────────────────────────────────────────────────────

  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setInt(String key, int value) async {
    try {
      await _prefs.setInt(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setInt($key) failed', e, st);
    }
  }

  // ── Double ───────────────────────────────────────────────────────────────

  double? getDouble(String key) => _prefs.getDouble(key);

  Future<void> setDouble(String key, double value) async {
    try {
      await _prefs.setDouble(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setDouble($key) failed', e, st);
    }
  }

  // ── StringList ───────────────────────────────────────────────────────────

  List<String>? getStringList(String key) => _prefs.getStringList(key);

  Future<void> setStringList(String key, List<String> value) async {
    try {
      await _prefs.setStringList(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setStringList($key) failed', e, st);
    }
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  bool containsKey(String key) => _prefs.containsKey(key);

  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
    } catch (e, st) {
      appLogger.error('LocalStorage remove($key) failed', e, st);
    }
  }

  Future<void> clear() async {
    try {
      await _prefs.clear();
    } catch (e, st) {
      appLogger.error('LocalStorage clear() failed', e, st);
    }
  }
}
