import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/app_urls.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/updater/android_sideload_updater.dart';
import 'package:lantern/core/updater/winsparkle_build_version.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class Updater with UpdaterListener {
  Updater({
    AndroidSideloadUpdater? androidSideloadUpdater,
    AutoUpdater? autoUpdater,
    Future<Map<String, dynamic>> Function()? loadFeatureFlags,
    @visibleForTesting TargetPlatform? platform,
    @visibleForTesting bool? isDebugMode,
    @visibleForTesting DateTime Function()? now,
    Future<void> Function()? quitForUpdate,
  }) : _androidSideloadUpdater =
           androidSideloadUpdater ?? AndroidSideloadUpdater(),
       _autoUpdater = autoUpdater,
       _loadFeatureFlags = loadFeatureFlags ?? _readFeatureFlags,
       _platform = platform ?? defaultTargetPlatform,
       _isDebugMode = isDebugMode ?? kDebugMode,
       _now = now ?? DateTime.now,
       _quitForUpdate = quitForUpdate;

  static const startupDelay = Duration(seconds: 5);
  static const featureFlagTimeout = Duration(seconds: 2);
  static const recoveryDelay = Duration(minutes: 1);
  static const _regularCheckInterval = Duration(hours: 1);
  static const _retryDelays = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  final AndroidSideloadUpdater _androidSideloadUpdater;
  final Future<Map<String, dynamic>> Function() _loadFeatureFlags;
  final TargetPlatform _platform;
  final bool _isDebugMode;
  final DateTime Function() _now;
  final Future<void> Function()? _quitForUpdate;

  AutoUpdater? _autoUpdater;
  Future<Map<String, dynamic>>? _pendingFeatureFlags;
  Map<String, dynamic> _cachedFeatureFlags = {};
  Timer? _checkTimer;
  DateTime? _nextCheckAt;
  String? _noUpdateMessage;
  int _retryAttempt = 0;
  bool _desktopConfigured = false;
  bool _started = false;
  bool _dispatchingCheck = false;
  bool _needsRetry = false;
  bool _updateOffered = false;
  bool _disposed = false;
  bool _listenerRegistered = false;
  bool _quittingForUpdate = false;

  bool get _isWindowsPlatform => !kIsWeb && _platform == TargetPlatform.windows;
  bool get _isAndroidPlatform => !kIsWeb && _platform == TargetPlatform.android;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (_platform == TargetPlatform.macOS ||
          _isWindowsPlatform ||
          _isAndroidPlatform);

  // AutoUpdater opens its native event channel as soon as the singleton is
  // created. Keep that initialization off Linux and Android, where the
  // desktop plugin is not registered.
  AutoUpdater get _desktopAutoUpdater => _autoUpdater ??= AutoUpdater.instance;

  Future<void> init() async {
    if (_started || _disposed || _isDebugMode || !_isSupportedPlatform) return;
    _started = true;
    if (_isAndroidPlatform) {
      try {
        await _androidSideloadUpdater.init(await _featureFlags());
      } catch (e, st) {
        _started = false;
        appLogger.error('Failed to initialize Android updater', e, st);
      }
    } else {
      _scheduleCheck(startupDelay, 'startup');
    }
  }

  Future<bool> canCheckForUpdates() async {
    if (!_isSupportedPlatform) return false;
    try {
      final flags = await _featureFlags();
      if (_isAndroidPlatform) {
        return _androidSideloadUpdater.isEnabled(flags, logDisabled: false);
      }
      return flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true);
    } catch (e, st) {
      appLogger.error('Failed to determine update-check availability', e, st);
      return false;
    }
  }

  Future<void> _configureDesktopUpdater() async {
    final buildType = AppBuildInfo.buildType;
    final feedUrl = AppUrls.appcastFor(buildType);
    final autoUpdater = _desktopAutoUpdater;
    if (!_listenerRegistered) {
      autoUpdater.addListener(this);
      _listenerRegistered = true;
    }
    if (_isWindowsPlatform) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        setWinSparkleBuildVersion(packageInfo.buildNumber);
      } catch (e, st) {
        appLogger.warning('Failed to set WinSparkle build version', e, st);
      }
    }
    await autoUpdater.setFeedURL(feedUrl);
    if (_disposed) return;
    await autoUpdater.setScheduledCheckInterval(
      _regularCheckInterval.inSeconds,
    );

    appLogger.info('autoUpdater configured. buildType=$buildType url=$feedUrl');
    _desktopConfigured = true;
  }

  Future<void> checkNow() async {
    if (_disposed || !_isSupportedPlatform) return;
    if (_isAndroidPlatform) {
      await init();
      final flags = await _featureFlags();
      if (!_androidSideloadUpdater.isEnabled(flags)) return;
      await _androidSideloadUpdater.checkForUpdate(
        source: AndroidSideloadUpdateCheckSource.manual,
      );
      return;
    }
    await _checkDesktop(inBackground: false, source: 'manual');
  }

  Future<void> _checkDesktop({
    required bool inBackground,
    required String source,
  }) async {
    if (_disposed || _dispatchingCheck || _quittingForUpdate) return;
    _dispatchingCheck = true;
    _cancelScheduledCheck();
    try {
      final flags = await _featureFlags();
      if (_disposed) return;
      if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
        _resetRetries();
        appLogger.info('autoUpdater disabled by feature flag');
        return;
      }
      if (!_desktopConfigured) await _configureDesktopUpdater();
      if (_disposed) return;
      appLogger.info(
        'Desktop update check: source=$source '
        'url=${AppUrls.appcastFor(AppBuildInfo.buildType)}',
      );
      _needsRetry = false;
      _updateOffered = false;
      _noUpdateMessage = null;
      await _desktopAutoUpdater.checkForUpdates(inBackground: inBackground);
    } catch (e, st) {
      appLogger.error('Failed to start desktop update check ($source)', e, st);
      _scheduleRetry();
      if (!inBackground) rethrow;
    } finally {
      // The method channel returns before the native check finishes.
      // Result callbacks, rather than this future, reset the retry budget.
      _dispatchingCheck = false;
    }
  }

  void _scheduleCheck(Duration delay, String source) {
    if (_disposed || _isDebugMode || _isAndroidPlatform) return;
    final checkAt = _now().add(delay);
    final nextCheckAt = _nextCheckAt;
    // Repeated reconnects should never push an earlier check back.
    if (nextCheckAt != null && !nextCheckAt.isAfter(checkAt)) return;
    _checkTimer?.cancel();
    _nextCheckAt = checkAt;
    _checkTimer = Timer(delay, () {
      _checkTimer = null;
      _nextCheckAt = null;
      unawaited(_checkDesktop(inBackground: true, source: source));
    });
  }

  void _scheduleRetry() {
    if (_disposed || _quittingForUpdate) return;
    _needsRetry = true;
    if (_checkTimer?.isActive == true) return;
    if (_retryAttempt == _retryDelays.length) {
      // Native hourly checks are only configured after setup succeeds.
      if (!_desktopConfigured) {
        _scheduleCheck(_regularCheckInterval, 'configuration-retry');
      }
      return;
    }
    final delay = _retryDelays[_retryAttempt];
    _retryAttempt++;
    appLogger.info(
      'Retrying desktop update check in ${delay.inSeconds}s '
      '(attempt $_retryAttempt)',
    );
    _scheduleCheck(delay, 'retry');
  }

  /// Gives a failed check another chance after reconnecting or resuming.
  void retryPendingCheck() {
    if (!_needsRetry ||
        _disposed ||
        _isDebugMode ||
        _isAndroidPlatform ||
        _dispatchingCheck) {
      return;
    }
    _scheduleCheck(recoveryDelay, 'recovery');
  }

  void _resetRetries() {
    _needsRetry = false;
    _retryAttempt = 0;
    _cancelScheduledCheck();
  }

  void _cancelScheduledCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _nextCheckAt = null;
  }

  void dispose() {
    _disposed = true;
    _cancelScheduledCheck();
    if (_listenerRegistered) _autoUpdater?.removeListener(this);
  }

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    if (!_isWindowsPlatform || _quittingForUpdate) return;
    _quittingForUpdate = true;
    appLogger.info('WinSparkle is ready to install; shutting down Lantern');
    unawaited(_shutdownForWindowsUpdate());
  }

  Future<void> _shutdownForWindowsUpdate() async {
    try {
      await (_quitForUpdate ?? _quitDesktopForUpdate)();
    } catch (e, st) {
      _quittingForUpdate = false;
      appLogger.error('Failed to shut down for Windows update', e, st);
    }
  }

  Future<void> _quitDesktopForUpdate() async {
    // WinSparkle has already launched the installer when it sends this event.
    // Tear down Lantern's desktop UI so the installer can replace the binary.
    try {
      await windowManager.setPreventClose(false);
    } catch (e, st) {
      appLogger.warning('Failed to release the Lantern window', e, st);
    }
    try {
      await trayManager.destroy();
    } catch (e, st) {
      appLogger.warning('Failed to close the Lantern tray icon', e, st);
    }
    try {
      await windowManager.destroy();
    } catch (e, st) {
      appLogger.warning('Failed to close the Lantern window', e, st);
    }
    exit(0);
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {
    _updateOffered = false;
    _noUpdateMessage = null;
  }

  @override
  void onUpdaterError(UpdaterError? error) {
    // Sparkle also reports "no update" through its error callback. The bridge
    // only exposes the message, so match it to the preceding result.
    final noUpdateMessage = _noUpdateMessage;
    _noUpdateMessage = null;
    if (error != null && error.message == noUpdateMessage) return;
    appLogger.warning(
      'Desktop update failed: '
      '${error?.message ?? 'native updater did not provide error details'} '
      'url=${AppUrls.appcastFor(AppBuildInfo.buildType)}',
    );
    // Once an update is offered, let the native UI handle download retries.
    if (!_updateOffered) _scheduleRetry();
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {
    _updateOffered = true;
    _resetRetries();
    appLogger.info('Desktop update available');
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {
    _resetRetries();
    appLogger.info('Desktop update downloaded');
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    _noUpdateMessage = error?.message;
    _resetRetries();
  }

  Future<Map<String, dynamic>> _featureFlags() async {
    // A Dart timeout doesn't cancel the IPC call. Reuse it while it's pending
    // so retries don't leave more requests waiting on an unresponsive core.
    final pending = _pendingFeatureFlags ??= Future.sync(_loadFeatureFlags)
        .then((flags) {
          _cachedFeatureFlags = flags;
          return flags;
        })
        .whenComplete(() {
          _pendingFeatureFlags = null;
        });
    try {
      return await pending.timeout(featureFlagTimeout);
    } catch (e) {
      appLogger.warning('Using cached update feature flags: $e');
      return _cachedFeatureFlags;
    }
  }

  static Future<Map<String, dynamic>> _readFeatureFlags() async {
    if (!sl.isRegistered<LanternService>() ||
        !sl.isReadySync<LanternService>()) {
      throw StateError('LanternService is not ready');
    }
    final flagResult = await sl<LanternService>().featureFlag();
    return flagResult.fold(
      (failure) =>
          throw StateError('Feature flags unavailable: ${failure.error}'),
      (jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }
}
