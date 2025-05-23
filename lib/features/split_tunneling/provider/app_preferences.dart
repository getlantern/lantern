import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_preferences.g.dart';

class Preferences {
  static const String splitTunnelingEnabled = "split_tunneling_enabled";
  static const String splitTunnelingMode = "split_tunneling_mode";
  static const String defaultBypassList = "default_bypass_list";
  static const String enabledApps = "enabled_apps";
}

@Riverpod(keepAlive: true)
class AppPreferences extends _$AppPreferences {
  late final LocalStorageService _db;

  @override
  Future<Map<String, dynamic>> build() async {
    _db = sl<LocalStorageService>();

    return {
      Preferences.splitTunnelingEnabled:
          _db.get<bool>(Preferences.splitTunnelingEnabled) ?? false,
      Preferences.defaultBypassList: BypassListOption.values.firstWhere(
        (option) =>
            option == _db.get<BypassListOption>(Preferences.defaultBypassList),
        orElse: () => BypassListOption.global,
      ),
      Preferences.splitTunnelingMode: SplitTunnelingMode.values.firstWhere(
        (mode) =>
            mode.displayName == _db.get<String>(Preferences.splitTunnelingMode),
        orElse: () => SplitTunnelingMode.automatic,
      ),
    };
  }

  Future<void> setPreference(String key, dynamic value) async {
    state = AsyncData({...state.value ?? {}, key: value});
    AppDB.set(key, value is SplitTunnelingMode ? value.displayName : value);
  }

  Future<void> setBypassList(BypassListOption value) async {
    state =
        AsyncData({...state.value ?? {}, Preferences.defaultBypassList: value});
    _db.set(Preferences.defaultBypassList, value);
  }
}
