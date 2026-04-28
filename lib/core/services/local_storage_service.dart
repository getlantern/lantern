import 'dart:convert';

import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/developer_mode.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A wrapper around [SharedPreferencesWithCache].

/// All getters are **synchronous** (reads come from the in-memory cache).
/// All setters are **async** (write through to platform storage and update
/// the cache).
class LocalStorageService {
  late SharedPreferencesWithCache _prefs;

  /// Keys for stored values
  static const _appSettingsKey = 'app_settings_json';
  static const _plansKey = 'plans_json';
  static const _developerModeKey = 'developer_mode_json';
  static const _serverLocationKey = 'server_location_json';

  Future<void> init() async {
    _prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions());
  }

  // ── AppSetting ────────────────────────────────────────────────────────────

  AppSetting? getAppSettings() {
    final raw = getString(_appSettingsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppSetting.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e, st) {
      appLogger.error('Failed to parse stored app settings', e, st);
    }
    return null;
  }

  Future<void> saveAppSettings(AppSetting settings) async {
    await setString(_appSettingsKey, jsonEncode(settings.toJson()));
  }

  // ── PlansData ─────────────────────────────────────────────────────────────

  PlansData? getPlans() {
    final raw = getString(_plansKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PlansData.fromJson(decoded);
    } catch (e, st) {
      appLogger.error('Error reading cached plans from prefs', e, st);
    }
    return null;
  }

  Future<void> savePlans(PlansData plans) async {
    await setString(_plansKey, jsonEncode(plans.toJson()));
  }

  // ── ServerLocation ────────────────────────────────────────────────────────

  ServerLocation? getServerLocation() {
    final raw = getString(_serverLocationKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ServerLocation.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e, st) {
      appLogger.error('Failed to parse stored server location', e, st);
    }
    return null;
  }

  Future<void> saveServerLocation(ServerLocation location) async {
    await setString(_serverLocationKey, jsonEncode(location.toJson()));
  }

  // ── DeveloperMode ─────────────────────────────────────────────────────────

  DeveloperMode? getDeveloperMode() {
    final raw = getString(_developerModeKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DeveloperMode.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveDeveloperMode(DeveloperMode dev) async {
    await setString(_developerModeKey, jsonEncode(dev.toJson()));
  }

  // Helper methods for basic types

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setString($key) failed', e, st);
    }
  }

  List<String>? getStringList(String key) => _prefs.getStringList(key);

  Future<void> setStringList(String key, List<String> value) async {
    try {
      await _prefs.setStringList(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setStringList($key) failed', e, st);
    }
  }

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

  Future<void> deleteAll() async {
    await clear();
  }
}
