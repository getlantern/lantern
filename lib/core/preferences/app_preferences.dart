import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/split_tunneling/split_tunneling_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'app_preferences.g.dart';

class Preferences {
  static const String splitTunnelingEnabled = "split_tunneling_enabled";
  static const String splitTunnelingMode = "split_tunneling_mode";
  static const String enabledApps = "enabled_apps";
}

@riverpod
class AppPreferences extends _$AppPreferences {
  late SharedPreferences _prefs;

  @override
  Future<Map<String, dynamic>> build() async {
    _prefs = await SharedPreferences.getInstance();

    return {
      Preferences.splitTunnelingEnabled:
          _prefs.getBool(Preferences.splitTunnelingEnabled) ?? false,
    };
  }

  Future<void> setPreference(String key, dynamic value) async {
    state = AsyncData({...state.value ?? {}, key: value});

    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is SplitTunnelingMode) {
      await _prefs.setString(key, value.displayName);
    } else {
      throw ArgumentError('Unsupported preference type for key: $key');
    }
  }
}
