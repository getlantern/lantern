import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

part 'app_setting_notifier.g.dart';

@Riverpod(keepAlive: true)
class AppSettingNotifier extends _$AppSettingNotifier {
  static const _settingsPrefsKey = 'app_settings_json';
  bool _didAttemptLoad = false;

  @override
  AppSetting build() {
    // First-time fallback, then asynchronously hydrate from prefs.
    final fallback = _detectDeviceLocale();
    final initial = AppSetting(locale: fallback.toString());
    unawaited(_loadFromPrefs(initial));
    unawaited(_detectEnvironmentFromFile());
    return initial;
  }

  Future<void> update(AppSetting updated) async {
    state = updated;
    await _saveToPrefs(updated);
  }

  void togglePro(bool value) => update(state.copyWith(newPro: value));

  void setLocale(String locale) {
    update(state.copyWith(newLocale: locale));
  }

  void toggleSplitTunneling(bool value) =>
      update(state.copyWith(newIsSpiltTunnelingOn: value));

  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) async {
    final prev = state.routingModeRaw;

    appLogger.info('Setting routing mode to: ${mode.key}');
    update(state.copyWith(routingModeRaw: mode.key));

    final lantern = ref.read(lanternServiceProvider);
    final res = await lantern.setRoutingMode(mode == RoutingMode.smart);

    res.fold((f) {
      appLogger.error('Failed to set routing mode', f);
      update(state.copyWith(routingModeRaw: prev));
    }, (_) {});
    return res;
  }

  void setUserLoggedIn(bool value) =>
      update(state.copyWith(userLoggedIn: value));
  void setOAuthToken(String token) => update(state.copyWith(oAuthToken: token));
  void setEmail(String email) => update(state.copyWith(email: email));
  void setSuccessfulConnection(bool value) =>
      update(state.copyWith(successfulConnection: value));

  void setBlockAds(bool value) {
    final prev = state.blockAds;
    update(state.copyWith(blockAds: value));

    final svc = ref.read(lanternServiceProvider);
    svc.setBlockAdsEnabled(value).then((res) {
      res.match((err) {
        appLogger.error('setBlockAdsEnabled failed: ${err.error}');
        update(state.copyWith(blockAds: prev));
      }, (_) {});
    });
  }

  void updateAnonymousDataConsent(bool value) {
    update(state.copyWith(telemetryConsent: value));
    updateTelemetryConsent(value);
  }

  void updateDataCapThreshold(String threshold) =>
      update(state.copyWith(dataCapThreshold: threshold));

  void setSplashScreen(bool value) =>
      update(state.copyWith(showSplashScreen: value));

  void setShowTelemetryDialog(bool value) =>
      update(state.copyWith(showTelemetryDialog: value));

  void setOnboardingCompleted(bool value) =>
      update(state.copyWith(onboardingCompleted: value));

  void setThemeMode(String mode) {
    update(state.copyWith(themeMode: mode));
    unawaited(_applyDesktopBrightness(resolveThemeMode(mode)));
  }

  void syncDesktopBrightnessFromCurrentTheme() {
    unawaited(_applyDesktopBrightness(resolveThemeMode(state.themeMode)));
  }

  Locale _detectDeviceLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'en'
        ? const Locale('en', 'US')
        : deviceLocale;
  }

  Future<void> _loadFromPrefs(AppSetting fallback) async {
    if (_didAttemptLoad) return;
    _didAttemptLoad = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_settingsPrefsKey);
      if (raw == null || raw.isEmpty) {
        await prefs.setString(_settingsPrefsKey, jsonEncode(fallback.toJson()));
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = AppSetting.fromJson(Map<String, dynamic>.from(decoded));
        unawaited(
          _applyDesktopBrightness(resolveThemeMode(state.themeMode)),
        );
      }
    } catch (e, st) {
      appLogger.error(
          'Failed to load app settings from SharedPreferences', e, st);
    }
  }

  Future<void> _saveToPrefs(AppSetting value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsPrefsKey, jsonEncode(value.toJson()));
    } catch (e, st) {
      appLogger.error(
          'Failed to persist app settings to SharedPreferences', e, st);
    }
  }

  Future<void> _applyDesktopBrightness(ThemeMode mode) async {
    if (!PlatformUtils.isDesktop) {
      return;
    }

    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => PlatformDispatcher.instance.platformBrightness,
    };

    try {
      await windowManager.setBrightness(brightness);
    } catch (e, st) {
      appLogger.error('Failed to set desktop toolbar brightness: $e', st);
    }
  }

  Future<void> setEnvironment(bool isStaging) async {
    final env = isStaging ? 'stage' : 'prod';
    update(state.copyWith(environment: env));

    final dir = await AppStorageUtils.getAppDirectory();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    if (isStaging) {
      final file = File('${dir.path}/.radiance_env');
      await file.create();
    }
  }

  Future<void> _detectEnvironmentFromFile() async {
    final dir = await AppStorageUtils.getAppDirectory();
    final envFile = File('${dir.path}/.radiance_env');
    final env = envFile.existsSync() ? 'stage' : 'prod';
    update(state.copyWith(environment: env));
  }

  Future<void> setSplitTunnelingEnabled(bool enabled) async {
    final LanternService svc = ref.read(lanternServiceProvider);
    final previous = state.isSplitTunnelingOn;

    update(state.copyWith(newIsSpiltTunnelingOn: enabled));
    appLogger.info('Setting split tunneling: $enabled');
    final res = await svc.setSplitTunnelingEnabled(enabled);
    res.match((err) {
      appLogger.error('setSplitTunnelingEnabled failed: ${err.error}');
      update(state.copyWith(newIsSpiltTunnelingOn: previous));
    }, (_) {});
  }

  Future<void> updateTelemetryConsent(bool consent) async {
    final result =
        await ref.read(lanternServiceProvider).updateTelemetryEvents(consent);

    result.fold(
      (err) {
        /// if fail revert the state
        update(state.copyWith(telemetryConsent: !consent));
        appLogger.error('updateTelemetryEvents failed: ${err.error}');
      },
      (_) {
        appLogger.info('Telemetry consent updated: $consent');
      },
    );
  }
}
