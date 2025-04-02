import 'dart:convert';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/split_tunneling/website.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'website_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingWebsites extends _$SplitTunnelingWebsites {
  static const String enabledWebsitesKey = "enabled_websites";

  @override
  List<Website> build() {
    _loadEnabledWebsites();
    return [];
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
        : [...state, website.copyWith(isEnabled: true)];

    // Save updated list
    final jsonString = jsonEncode(state.map((app) => app.toJson()).toList());
    await prefs.setString(enabledWebsitesKey, jsonString);

    // Also update AppPreferencesNotifier for persistence
    ref
        .read(appPreferencesProvider.notifier)
        .setPreference(enabledWebsitesKey, jsonString);
  }
}
