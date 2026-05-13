import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';
import 'package:lantern/lantern/lantern_service.dart';

class Updater {
  Updater({AndroidSideloadUpdater? androidSideloadUpdater})
    : _androidSideloadUpdater =
          androidSideloadUpdater ?? AndroidSideloadUpdater();

  final AndroidSideloadUpdater _androidSideloadUpdater;

  bool _initialized = false;

  bool get _isDesktopSupportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  bool get _isAndroidPlatform => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) return;
    if (!_isDesktopSupportedPlatform && !_isAndroidPlatform) return;

    final flags = await _featureFlags();

    if (_isAndroidPlatform) {
      await _androidSideloadUpdater.init(flags);
      return;
    }

    await _initDesktopUpdater(flags);
  }

  Future<bool> canCheckForUpdates() async {
    if (_isDesktopSupportedPlatform) return true;
    if (!_isAndroidPlatform) return false;

    try {
      final flags = await _featureFlags();
      return _androidSideloadUpdater.isEnabled(flags, logDisabled: false);
    } catch (e, st) {
      appLogger.error('Failed to determine update-check availability', e, st);
      return false;
    }
  }

  Future<void> _initDesktopUpdater(Map<String, dynamic> flags) async {
    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      appLogger.info('autoUpdater disabled by feature flag');
      return;
    }

    try {
      final buildType = AppBuildInfo.buildType;
      final feedUrl = AppUrls.appcastFor(buildType);
      final updater = AutoUpdater.instance;
      await updater.setFeedURL(feedUrl);
      await updater.setScheduledCheckInterval(3600);

      // Background check after startup (avoid modal immediately on launch)
      const firstPromptDelay = Duration(seconds: 45);
      unawaited(
        Future<void>.delayed(firstPromptDelay, () async {
          try {
            await updater.checkForUpdates(inBackground: true);
          } catch (e, st) {
            appLogger.error('Failed to check for auto-updates', e, st);
          }
        }),
      );

      appLogger.info(
        'autoUpdater configured. buildType=$buildType url=$feedUrl',
      );
    } catch (e, st) {
      appLogger.error('Failed to configure autoUpdater:', e, st);
    }
  }

  Future<void> checkNow() async {
    if (_isAndroidPlatform) {
      final flags = await _featureFlags();
      if (!_androidSideloadUpdater.isEnabled(flags)) return;
      final update = await _androidSideloadUpdater.checkNow(
        source: AndroidSideloadUpdateCheckSource.manual,
      );
      if (update == null) {
        _showNoUpdateDialog();
      }
      return;
    }

    if (!_isDesktopSupportedPlatform) return;
    await AutoUpdater.instance.checkForUpdates();
  }

  Future<Map<String, dynamic>> _featureFlags() async {
    final flagResult = await sl<LanternService>().featureFlag();
    return flagResult.fold((_) => <String, dynamic>{}, (jsonStr) {
      try {
        return json.decode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    });
  }

  void _showNoUpdateDialog() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.dialog(
      context: context,
      title: 'check_for_updates'.i18n,
      content: 'lantern_is_up_to_date'.i18n,
    );
  }
}
