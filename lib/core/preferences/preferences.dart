import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesNotifier extends StateNotifier<Map<String, dynamic>> {
  static const String splitTunnelingEnabled = "split_tunneling_enabled";
  static const String enabledAppsKey = "enabled_apps";

  AppPreferencesNotifier() : super({}) {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = {
      splitTunnelingEnabled: prefs.getBool(splitTunnelingEnabled) ?? false,
    };
  }

  Future<void> setPreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    state = {...state, key: value};

    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, Map<String, dynamic>>(
  (ref) => AppPreferencesNotifier(),
);
