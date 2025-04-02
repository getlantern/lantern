import 'dart:convert';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  static const String enabledAppsKey = Preferences.enabledApps;

  @override
  Set<AppData> build() {
    _loadEnabledApps();
    return {};
  }

  // Load enabled apps from SharedPreferences
  Future<void> _loadEnabledApps() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    final jsonString = prefs[enabledAppsKey];

    if (jsonString == null) return;

    final List decodedList = jsonDecode(jsonString);
    state = decodedList.map((json) => AppData.fromJson(json)).toSet();
  }

  // Toggle app selection for split tunneling
  Future<void> toggleApp(AppData app) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = app.isEnabled;
    final isCurrentlyEnabled = state.any((a) => (a.name == app.name));

    Set<AppData> updatedState;
    if (isCurrentlyEnabled) {
      // Remove app if it's currently enabled
      updatedState = state.where((a) => (a.name != app.name)).toSet();
    } else {
      // Preserve existing state and toggle app isEnabled
      updatedState = {...state, app.copyWith(isEnabled: isEnabled)};
    }

    state = updatedState;

    // Save updated list
    final jsonString = jsonEncode(state.map((app) => app.toJson()).toList());
    await prefs.setString(enabledAppsKey, jsonString);
    ref
        .read(appPreferencesProvider.notifier)
        .setPreference(enabledAppsKey, jsonString);
  }
}
