import 'dart:async';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';

class Updater {
  Updater({AutoUpdater? updater}) : _updater = updater ?? autoUpdater;

  final AutoUpdater _updater;

  bool _initialized = false;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  Future<void> init({required Map<String, dynamic> flags}) async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) return;
    if (!_isSupportedPlatform) return;

    final enabled = flags.getBool(FeatureFlag.autoUpdateEnabled);
    if (!enabled) return;

    final buildType = AppBuildInfo.buildType;
    final feedUrl = AppUrls.appcastFor(buildType);

    try {
      await _updater.setFeedURL(feedUrl);
      await _updater.setScheduledCheckInterval(3600);

      // Background check after startup (avoid modal immediately on launch)
      const firstPromptDelay = Duration(seconds: 45);
      unawaited(Future<void>.delayed(firstPromptDelay, () async {
        try {
          await _updater.checkForUpdates(inBackground: true);
        } catch (e, st) {
          appLogger.error('Failed to check for auto-updates: $e', st);
        }
      }));

      appLogger
          .info('autoUpdater configured. buildType=$buildType url=$feedUrl');
    } catch (e, st) {
      appLogger.error('Failed to configure autoUpdater: $e', st);
    }
  }

  Future<void> checkNow() async {
    if (!_isSupportedPlatform) return;
    await _updater.checkForUpdates();
  }
}
