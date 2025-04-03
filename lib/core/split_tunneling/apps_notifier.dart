import 'dart:convert';
import 'package:lantern/core/preferences/app_preferences.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  late final LocalStorageService _db;

  @override
  Set<AppData> build() {
    _db = sl<LocalStorageService>();
    return _db.getEnabledApps();
  }

  // Toggle app selection for split tunneling
  Future<void> toggleApp(AppData app) async {
    final isCurrentlyEnabled = state.any((a) => a.name == app.name);

    if (isCurrentlyEnabled) {
      state = state.where((a) => a.name != app.name).toSet();
    } else {
      state = {...state, app.copyWith(isEnabled: true)};
    }

    _db.saveApps(state);
  }
}
