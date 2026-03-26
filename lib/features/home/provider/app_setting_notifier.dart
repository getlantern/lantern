import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_transition_origin_tracker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'app_setting_notifier.g.dart';

@Riverpod(keepAlive: true)
class AppSettingNotifier extends _$AppSettingNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();
  bool _isRoutingModeUpdateInFlight = false;
  bool _isBlockAdsUpdateInFlight = false;

  @override
  AppSetting build() {
    final settings = _fetchStoredSettings();
    unawaited(_applyDesktopBrightness(resolveThemeMode(settings.themeMode)));
    unawaited(_detectEnvironmentFromFile());
    return settings;
  }

  /// Reads app settings from local storage. Returns stored settings if found
  /// and valid, otherwise initializes and returns defaults.
  AppSetting _fetchStoredSettings() {
    final fallback = AppSetting(locale: _detectDeviceLocale().toString());
    final settings = _storage.getAppSettings();

    if (settings == null) {
      appLogger.info(
        'No stored settings found, saving defaults: ${_settingsLogFields(fallback)}',
      );
      unawaited(_storage.saveAppSettings(fallback));
      return fallback;
    }

    appLogger.info(
      'Loaded stored app settings: ${_settingsLogFields(settings)}',
    );
    return settings;
  }

  Future<void> update(AppSetting updated) async {
    appLogger.info('Updating app settings: ${_settingsLogFields(updated)}');
    state = updated;
    await _storage.saveAppSettings(updated);
  }

  void togglePro(bool value) => update(state.copyWith(newPro: value));

  void setLocale(String locale) {
    update(state.copyWith(newLocale: locale));
  }

  void toggleSplitTunneling(bool value) =>
      update(state.copyWith(newIsSpiltTunnelingOn: value));

  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) async {
    if (state.routingMode == mode) {
      return right(unit);
    }

    if (_isRoutingModeUpdateInFlight) {
      appLogger.info(
        'Routing mode update already in progress. Ignoring duplicate request.',
      );
      return right(unit);
    }

    _isRoutingModeUpdateInFlight = true;
    final prev = state.routingModeRaw;

    appLogger.info('Setting routing mode to: ${mode.key}');
    await update(state.copyWith(routingModeRaw: mode.key));

    try {
      final lantern = ref.read(lanternServiceProvider);
      final tracker = ref.read(vpnTransitionOriginTrackerProvider);
      final res = await tracker.runAsSettingsMutation(
        () => lantern.setRoutingMode(mode == RoutingMode.smart),
      );

      await res.match((f) async {
        appLogger.error('Failed to set routing mode', f);
        await update(state.copyWith(routingModeRaw: prev));
      }, (_) async {});
      return res;
    } finally {
      _isRoutingModeUpdateInFlight = false;
    }
  }

  void setUserLoggedIn(bool value) =>
      update(state.copyWith(userLoggedIn: value));

  void setOAuthTokenAndProvider(String token, String provider) {
    update(state.copyWith(oAuthToken: token, oAuthLoginProvider: provider));
  }

  void setEmail(String email) => update(state.copyWith(email: email));

  void setSuccessfulConnection(bool value) =>
      update(state.copyWith(successfulConnection: value));

  void setBlockAds(bool value) {
    unawaited(_setBlockAds(value));
  }

  Future<void> _setBlockAds(bool value) async {
    if (state.blockAds == value) {
      return;
    }

    if (_isBlockAdsUpdateInFlight) {
      appLogger.info(
        'Block ads update already in progress. Ignoring duplicate request.',
      );
      return;
    }

    _isBlockAdsUpdateInFlight = true;
    final prev = state.blockAds;
    await update(state.copyWith(blockAds: value));

    try {
      final svc = ref.read(lanternServiceProvider);
      final tracker = ref.read(vpnTransitionOriginTrackerProvider);
      final res = await tracker.runAsSettingsMutation(
        () => svc.setBlockAdsEnabled(value),
      );

      await res.match((err) async {
        appLogger.error('setBlockAdsEnabled failed: ${err.error}');
        await update(state.copyWith(blockAds: prev));
      }, (_) async {});
    } finally {
      _isBlockAdsUpdateInFlight = false;
    }
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
    sl<LocalStorageService>().deleteAll();

    if (isStaging) {
      final file = File('${dir.path}/.radiance_env');
      await file.create();
    }
    appLogger.info('Environment set to: $env');
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
    final result = await ref
        .read(lanternServiceProvider)
        .updateTelemetryEvents(consent);

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

  Map<String, Object> _settingsLogFields(AppSetting setting) => {
    'isPro': setting.isPro,
    'isSplitTunnelingOn': setting.isSplitTunnelingOn,
    'themeMode': setting.themeMode,
    'environment': setting.environment,
    'locale': setting.locale,
    'userLoggedIn': setting.userLoggedIn,
    'blockAds': setting.blockAds,
    'showSplashScreen': setting.showSplashScreen,
    'telemetryDialogDismissed': setting.telemetryDialogDismissed,
    'telemetryConsent': setting.telemetryConsent,
    'successfulConnection': setting.successfulConnection,
    'routingModeRaw': setting.routingModeRaw,
    'dataCapThreshold': setting.dataCapThreshold,
    'onboardingCompleted': setting.onboardingCompleted,
    'hasOAuthToken': setting.oAuthToken.isNotEmpty,
    'hasEmail': setting.email.isNotEmpty,
  };
}
