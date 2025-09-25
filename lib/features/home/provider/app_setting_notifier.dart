import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_eum.dart';
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

  void setSplitTunnelingMode(SplitTunnelingMode mode) {
    update(state.copyWith(newSplitTunnelingMode: mode));
  }

  void setUserLoggedIn(bool value) {
    update(state.copyWith(userLoggedIn: value));
  }

  void setOAuthToken(String token) {
    update(state.copyWith(oAuthToken: token));
  }

  void setEmail(String email) {
    update(state.copyWith(email: email));
  }

  void setBlockAds(bool value) {
    update(state.copyWith(blockAds: value));
  }

  void setSplashScreen(bool value) {
    update(state.copyWith(showSplashScreen: value));
  }

  Locale _detectDeviceLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'en'
        ? const Locale('en', 'US')
        : deviceLocale;
  }

  void setBypassList(BypassListOption list) {
    update(state.copyWith(newBypassList: list));
  }
}
