import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service.dart';

class Updater {
  bool _initialized = false;

  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) return;
    if (!_isSupportedPlatform) return;

    final flagResult = await sl<LanternService>().featureFlag();
    final flags = flagResult.fold((_) => <String, dynamic>{}, (jsonStr) {
      try {
        return json.decode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    });

    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      appLogger.info('autoUpdater disabled by feature flag');
      return;
    }

    final buildType = AppBuildInfo.buildType;
    final feedUrl = AppUrls.appcastFor(buildType);

    try {
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
    if (!_isSupportedPlatform) return;
    await AutoUpdater.instance.checkForUpdates();
  }
}
