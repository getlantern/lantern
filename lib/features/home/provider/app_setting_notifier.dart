import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
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

  void setRoutingMode(String mode) {
    update(state.copyWith(routingMode: mode));
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

  void setSuccessfulConnection(bool value) {
    update(state.copyWith(successfulConnection: value));
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

  void updateAnonymousDataConsent(bool value) {
    update(state.copyWith(telemetryConsent: value));
    updateTelemetryConsent(value);
  }

  void setSplashScreen(bool value) {
    update(state.copyWith(showSplashScreen: value));
  }

  void setShowTelemetryDialog(bool value) {
    update(state.copyWith(showTelemetryDialog: value));
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

  Future<void> updateTelemetryConsent(bool consent) async {
    final result =
        await ref.read(lanternServiceProvider).updateTelemetryEvents(consent);

    result.fold(
      (err) {
        ///if fail revert the state
        update(state.copyWith(telemetryConsent: consent ? false : true));
        appLogger.error('updateTelemetryEvents failed: ${err.error}');
      },
      (_) {
        appLogger.info('Telemetry consent updated: $consent');
        if (Platform.isWindows) {
          appLogger.info("No need to create telemetry file on Windows");
          return;
        }
        if (consent) {
          enableTelemetry();
        } else {
          disableTelemetry();
        }
      },
    );
  }

  ///Internal method to create a file that indicates telemetry is enabled
  Future<void> enableTelemetry() async {
    final dir = await AppStorageUtils.getAppDirectory();
    final file = File('${dir.path}/.telemetry_enabled');
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
  }

  ///Internal method to delete the file that indicates telemetry is disabled
  Future<void> disableTelemetry() async {
    final dir = await AppStorageUtils.getAppDirectory();
    final file = File('${dir.path}/.telemetry_enabled');
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
