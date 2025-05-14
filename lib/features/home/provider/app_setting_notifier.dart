import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_setting_notifier.g.dart';

@Riverpod(keepAlive: true)
class AppSettingNotifier extends _$AppSettingNotifier {
  late final LocalStorageService _db;

  @override
  AppSetting build() {
    _db = sl<LocalStorageService>();
    final setting = _db.getAppSetting();

    if (setting != null && setting.locale.isNotEmpty) {
      return setting;
    }
    // First-time user → use device locale
    final fallback = _detectDeviceLocale();
    final initial = AppSetting(locale: fallback.toString());

    _db.updateAppSetting(initial);
    return initial;
  }

  Future<void> update(AppSetting updated) async {
    state = updated;
     _db.updateAppSetting(updated);
  }

  void togglePro(bool value) {
    update(state.copyWith(newPro: value));
  }

  void setLocale(String locale) {
    update(state.copyWith(newLocale: locale));
  }

  void toggleSplitTunneling(bool value) {
    update(state.copyWith(newIsSpiltTunnelingOn: value));
  }

  void setSplitTunnelingMode(String mode) {
    update(state.copyWith(newSplitTunnelingMode: mode));
  }


  Locale _detectDeviceLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'en'
        ? const Locale('en', 'US')
        : deviceLocale;
  }
}
