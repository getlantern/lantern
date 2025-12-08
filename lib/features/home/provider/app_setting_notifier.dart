import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
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
    final prev = state.blockAds;
    update(state.copyWith(blockAds: value));

    final svc = ref.read(lanternServiceProvider);
    svc.setBlockAdsEnabled(value).then((res) {
      res.match(
        (err) {
          appLogger.error('setBlockAdsEnabled failed: ${err.error}');
          update(state.copyWith(blockAds: prev));
        },
        (_) {},
      );
    });
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

  void setBypassList(List<BypassListOption> list) {
    update(state.copyWith(newBypassList: list));
  }

  Future<void> setSplitTunnelingEnabled(bool enabled) async {
    final LanternService svc = ref.read(lanternServiceProvider);
    final previous = state.isSplitTunnelingOn;

    update(state.copyWith(newIsSpiltTunnelingOn: enabled));
    appLogger.info('Setting split tunneling: $enabled');
    final res = await svc.setSplitTunnelingEnabled(enabled);
    res.match(
      (err) {
        appLogger.error('setSplitTunnelingEnabled failed: ${err.error}');
        update(state.copyWith(newIsSpiltTunnelingOn: previous));
      },
      (_) {},
    );
  }
}
