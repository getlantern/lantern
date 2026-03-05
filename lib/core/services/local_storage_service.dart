import 'package:lantern/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A generic wrapper around [SharedPreferences].
///
/// Use this as the single access point for local key-value storage across
/// the app. Higher-level services (e.g. AppSettingNotifier) delegate to this.
class LocalStorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ── String ──────────────────────────────────────────────────────────────

  Future<String?> getString(String key) async {
    try {
      return (await _prefs).getString(key);
    } catch (e, st) {
      appLogger.error('LocalStorage getString($key) failed', e, st);
      return null;
    }
  }

  Future<bool> setString(String key, String value) async {
    try {
      return (await _prefs).setString(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setString($key) failed', e, st);
      return false;
    }
  }

  // ── Bool ─────────────────────────────────────────────────────────────────

  Future<bool?> getBool(String key) async {
    try {
      return (await _prefs).getBool(key);
    } catch (e, st) {
      appLogger.error('LocalStorage getBool($key) failed', e, st);
      return null;
    }
  }

  Future<bool> setBool(String key, bool value) async {
    try {
      return (await _prefs).setBool(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setBool($key) failed', e, st);
      return false;
    }
  }

  // ── Int ──────────────────────────────────────────────────────────────────

  Future<int?> getInt(String key) async {
    try {
      return (await _prefs).getInt(key);
    } catch (e, st) {
      appLogger.error('LocalStorage getInt($key) failed', e, st);
      return null;
    }
  }

  Future<bool> setInt(String key, int value) async {
    try {
      return (await _prefs).setInt(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setInt($key) failed', e, st);
      return false;
    }
  }

  // ── Double ───────────────────────────────────────────────────────────────

  Future<double?> getDouble(String key) async {
    try {
      return (await _prefs).getDouble(key);
    } catch (e, st) {
      appLogger.error('LocalStorage getDouble($key) failed', e, st);
      return null;
    }
  }

  Future<bool> setDouble(String key, double value) async {
    try {
      return (await _prefs).setDouble(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setDouble($key) failed', e, st);
      return false;
    }
  }

  // ── StringList ───────────────────────────────────────────────────────────

  Future<List<String>?> getStringList(String key) async {
    try {
      return (await _prefs).getStringList(key);
    } catch (e, st) {
      appLogger.error('LocalStorage getStringList($key) failed', e, st);
      return null;
    }
  }

  Future<bool> setStringList(String key, List<String> value) async {
    try {
      return (await _prefs).setStringList(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setStringList($key) failed', e, st);
      return false;
    }
  }

  // ── Utility ──────────────────────────────────────────────────────────────

  Future<bool> remove(String key) async {
    try {
      return (await _prefs).remove(key);
    } catch (e, st) {
      appLogger.error('LocalStorage remove($key) failed', e, st);
      return false;
    }
  }

  Future<bool> containsKey(String key) async {
    try {
      return (await _prefs).containsKey(key);
    } catch (e, st) {
      appLogger.error('LocalStorage containsKey($key) failed', e, st);
      return false;
    }
  }

  Future<bool> clear() async {
    try {
      return (await _prefs).clear();
    } catch (e, st) {
      appLogger.error('LocalStorage clear() failed', e, st);
      return false;
    }
  }
}
