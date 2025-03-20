import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/preferences/preferences.dart';
import 'package:lantern/core/providers/apps_data_provider.dart';
import 'package:lantern/core/split_tunneling/website.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_data.dart';

class SplitTunnelingAppsNotifier extends StateNotifier<Set<AppData>> {
  static const String enabledAppsKey = "enabled_apps";
  final Ref ref;

  SplitTunnelingAppsNotifier(
    this.ref,
  ) : super({}) {
    _loadEnabledApps();
  }

  // Load enabled apps from SharedPreferences
  Future<void> _loadEnabledApps() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(enabledAppsKey);

    if (jsonString != null) {
      final List decodedList = jsonDecode(jsonString);
      state = decodedList.map((json) => AppData.fromJson(json)).toSet();
    }
  }

  // Toggle app selection for split tunneling
  Future<void> toggleApp(AppData app) async {
    final prefs = await SharedPreferences.getInstance();
    final name = app.name;
    final isEnabled = app.isEnabled;
    final current = jsonEncode(state.map((app) => app.toJson()).toList());
    print("current state is $current");
    print("app name $name isEnabled $isEnabled");
    final isCurrentlyEnabled = state.any((a) => (a.name == app.name));

    Set<AppData> updatedState;
    if (isCurrentlyEnabled) {
      // Remove app if it's currently enabled
      updatedState = state.where((a) => (a.name != app.name)).toSet();
    } else {
      // Preserve existing state and toggle `isEnabled`
      updatedState = {...state, app.copyWith(isEnabled: isEnabled)};
    }

    // Update state
    state = updatedState;

    // Save updated list
    final jsonString = jsonEncode(state.map((app) => app.toJson()).toList());
    await prefs.setString(enabledAppsKey, jsonString);
    print("json string is $jsonString");

    ref
        .read(appPreferencesProvider.notifier)
        .setPreference(enabledAppsKey, jsonString);
  }
}

class SplitTunnelingWebsiteNotifier extends StateNotifier<List<Website>> {
  static const String enabledWebsitesKey = "enabled_websites";
  final Ref ref;

  SplitTunnelingWebsiteNotifier(this.ref) : super([]) {
    _loadEnabledWebsites();
  }

  // Load enabled websites from SharedPreferences
  Future<void> _loadEnabledWebsites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(enabledWebsitesKey);

    if (jsonString != null) {
      final List decodedList = jsonDecode(jsonString);
      state = decodedList.map((json) => Website.fromJson(json)).toList();
    }
  }

  // Toggle website selection (domain) for split tunneling
  Future<void> toggleWebsite(Website website) async {
    final prefs = await SharedPreferences.getInstance();
    final isCurrentlyEnabled = state.any((a) => a.domain == website.domain);

    state = isCurrentlyEnabled
        ? state.where((a) => a.domain != website.domain).toList()
        : [
            ...state,
            website.copyWith(isEnabled: true)
          ]; // Add website as enabled

    // Save updated list
    final jsonString = jsonEncode(state.map((app) => app.toJson()).toList());
    await prefs.setString(enabledWebsitesKey, jsonString);

    // Also update AppPreferencesNotifier for persistence
    ref
        .read(appPreferencesProvider.notifier)
        .setPreference(enabledWebsitesKey, jsonString);
  }
}

final splitTunnelingAppsProvider =
    StateNotifierProvider<SplitTunnelingAppsNotifier, Set<AppData>>(
  (ref) => SplitTunnelingAppsNotifier(ref),
);

final splitTunnelingWebsitesProvider =
    StateNotifierProvider<SplitTunnelingWebsiteNotifier, List<Website>>(
  (ref) => SplitTunnelingWebsiteNotifier(ref),
);
