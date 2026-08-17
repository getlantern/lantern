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
  static const _seenReferralsKey = 'seen_converted_referrals';
  static const _seenBypassAppDialogKey = 'seen_bypass_app_dialog';
  static const _seenBypassWebsiteDialogKey = 'seen_bypass_website_dialog';

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

  // ── Referrals ─────────────────────────────────────────────────────────────

  /// User IDs of converted referrals the reward dialog was already shown for.
  List<String> getSeenConvertedReferrals() =>
      getStringList(_seenReferralsKey) ?? const [];

  Future<void> saveSeenConvertedReferrals(List<String> userIds) =>
      setStringList(_seenReferralsKey, userIds);

  // ── Split tunneling ───────────────────────────────────────────────────────

  /// Whether the one-time "Bypass the VPN for this app?" explainer was already
  /// shown when adding an app to the bypass list.
  bool get hasSeenBypassAppDialog =>
      getBool(_seenBypassAppDialogKey) ?? false;

  Future<void> markBypassAppDialogSeen() =>
      setBool(_seenBypassAppDialogKey, true);

  /// Whether the one-time "Bypass the VPN for this website?" explainer was
  /// already shown when adding a website to the bypass list.
  bool get hasSeenBypassWebsiteDialog =>
      getBool(_seenBypassWebsiteDialogKey) ?? false;

  Future<void> markBypassWebsiteDialogSeen() =>
      setBool(_seenBypassWebsiteDialogKey, true);

  // Helper methods for basic types

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) async {
    try {
      await _prefs.setString(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setString($key) failed', e, st);
    }
  }

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, bool value) async {
    try {
      await _prefs.setBool(key, value);
    } catch (e, st) {
      appLogger.error('LocalStorage setBool($key) failed', e, st);
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

  /// Reads a `Map<String, String>` persisted as a JSON object. Returns an
  /// empty map when the key is absent or holds an empty string, and clears the
  /// key when its (non-empty) contents can't be parsed into a map.
  Future<Map<String, String>> getStringMap(String key) async {
    final raw = getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      appLogger.warning('Stored map at "$key" had invalid shape; clearing');
    } catch (e, st) {
      appLogger.error('Failed to parse stored map at "$key"; clearing', e, st);
    }
    await remove(key);
    return {};
  }

  /// Persists a `Map<String, String>` as a JSON object, removing the key
  /// entirely when the map is empty.
  Future<void> setStringMap(String key, Map<String, String> value) async {
    if (value.isEmpty) {
      await remove(key);
      return;
    }
    await setString(key, jsonEncode(value));
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
