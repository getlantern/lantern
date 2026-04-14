import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'app_setting_notifier.g.dart';

/// Name of the marker file placed in the app data directory after first
/// successful initialization.  When SharedPreferences survive a data-dir
/// deletion (e.g. NSUserDefaults on macOS), the absence of this file tells
/// us to treat the launch as a fresh install and reset stored settings.
const _initMarkerName = '.app_initialized';

@Riverpod(keepAlive: true)
class AppSettingNotifier extends _$AppSettingNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  /// Must be called from [injectServices] (before `runApp`) so that stale
  /// SharedPreferences are cleared before any widget reads the provider.
  static Future<void> resetIfFreshInstall(LocalStorageService storage) async {
    final settings = storage.getAppSettings();
    if (settings == null || !settings.onboardingCompleted) {
      // Either no stored settings or onboarding hasn't been marked done —
      // nothing to reset.
      return;
    }

    final dataDir = await AppStorageUtils.getAppDirectory();
    final marker = File('${dataDir.path}/$_initMarkerName');
    if (marker.existsSync()) return;

    // Settings say onboarding is done, but the data-dir marker is missing.
    // This means the user deleted the data directory (clean install) while
    // SharedPreferences (NSUserDefaults / registry) survived.
    appLogger.info(
      'Stale settings detected (data dir was cleared), resetting to defaults',
    );
    await storage.saveAppSettings(const AppSetting());
    await marker.create();
  }

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

  void setLocale(String locale) {
    update(state.copyWith(newLocale: locale));
  }

  void setUserLoggedIn(bool value) =>
      update(state.copyWith(userLoggedIn: value));

  void setSuccessfulConnection(bool value) =>
      update(state.copyWith(successfulConnection: value));

  void updateDataCapThreshold(String threshold) =>
      update(state.copyWith(dataCapThreshold: threshold));

  void setSplashScreen(bool value) =>
      update(state.copyWith(showSplashScreen: value));

  void setShowTelemetryDialog(bool value) =>
      update(state.copyWith(showTelemetryDialog: value));

  void setOnboardingCompleted(bool value) {
    update(state.copyWith(onboardingCompleted: value));
    if (value) unawaited(_writeInitMarker());
  }

  Future<void> _writeInitMarker() async {
    try {
      final dataDir = await AppStorageUtils.getAppDirectory();
      final marker = File('${dataDir.path}/$_initMarkerName');
      if (!marker.existsSync()) await marker.create();
    } catch (e, st) {
      appLogger.error('Failed to write init marker', e, st);
    }
  }

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

  Map<String, Object> _settingsLogFields(AppSetting setting) => {
    'themeMode': setting.themeMode,
    'environment': setting.environment,
    'locale': setting.locale,
    'userLoggedIn': setting.userLoggedIn,
    'showSplashScreen': setting.showSplashScreen,
    'telemetryDialogDismissed': setting.telemetryDialogDismissed,
    'successfulConnection': setting.successfulConnection,
    'dataCapThreshold': setting.dataCapThreshold,
    'onboardingCompleted': setting.onboardingCompleted,
  };
}
