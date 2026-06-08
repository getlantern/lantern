import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/models/notification_event.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/core/utils/store_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

typedef AndroidSideloadInstaller =
    Future<String> Function(AndroidSideloadUpdate update);

enum AndroidSideloadUpdateCheckSource { startup, manual }

enum AndroidSideloadInstallStatus {
  installerStarted('installer_started'),
  permissionRequired('permission_required');

  const AndroidSideloadInstallStatus(this.tag);

  final String tag;
}

enum AndroidSideloadUpdateTelemetryEvent {
  checkResult('android_sideload_update_check_result'),
  updateAvailable('android_sideload_update_available'),
  downloadFailed('android_sideload_update_download_failed'),
  checksumFailed('android_sideload_update_checksum_failed'),
  installerLaunched('android_sideload_update_installer_launched'),
  installerPermissionRequired(
    'android_sideload_update_installer_permission_required',
  ),
  installFailed('android_sideload_update_install_failed');

  const AndroidSideloadUpdateTelemetryEvent(this.tag);

  final String tag;
}

void _trackTelemetry(
  AndroidSideloadUpdateTelemetryEvent event,
  Map<String, Object?> properties,
) {
  final sanitized = <String, Object?>{
    for (final entry in properties.entries)
      if (entry.value != null) entry.key: entry.value,
  };
  appLogger.info(
    'telemetry event=${event.tag} properties=${jsonEncode(sanitized)}',
  );
}

class AndroidSideloadUpdater {
  AndroidSideloadUpdater({
    http.Client? httpClient,
    AndroidSideloadInstaller? installer,
  }) : _httpClient = httpClient,
       _installer = installer ?? installSideloadUpdate;

  static const firstPromptDelay = Duration(seconds: 45);
  static const startupCheckThrottle = Duration(days: 1);
  static const requestTimeout = Duration(seconds: 20);
  static const _lastStartupCheckAtKey =
      'android_sideload_update_last_startup_check_at';

  final Uri endpoint = Uri.parse(AppUrls.androidSideloadUpdateEndpoint);
  final http.Client? _httpClient;
  final AndroidSideloadInstaller _installer;

  bool _initialized = false;
  String? _lastPromptedVersion;

  /// Schedules the first throttled startup update check after a short delay.
  /// Runs once per instance and is a no-op when the updater is disabled.
  Future<void> init(Map<String, dynamic> flags) async {
    if (_initialized) return;
    _initialized = true;
    if (!isEnabled(flags)) return;

    unawaited(
      Future<void>.delayed(firstPromptDelay, () async {
        try {
          await checkForUpdate(
            promptIfAvailable: true,
            source: AndroidSideloadUpdateCheckSource.startup,
            respectStartupThrottle: true,
          );
        } catch (e, st) {
          appLogger.error('Failed to check for Android sideload update', e, st);
        }
      }),
    );
  }

  /// Whether sideload auto-updates should run, based on build type and flags.
  bool isEnabled(Map<String, dynamic> flags, {bool logDisabled = false}) {
    if (!isSupportedSideloadBuild) return false;
    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      if (!logDisabled) {
        appLogger.info(
          'Android sideload updater disabled by autoUpdateEnabled',
        );
      }
      return false;
    }
    if (!flags.getBool(
      FeatureFlag.androidSideloadAutoUpdateEnabled,
      defaultValue: false,
    )) {
      if (!logDisabled) {
        appLogger.info(
          'Android sideload updater disabled by rollout feature flag',
        );
      }
      return false;
    }
    return true;
  }

  bool get isSupportedSideloadBuild {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (kDebugMode) return false;
    return _isSideLoaded();
  }

  /// Queries the update endpoint and returns a newer [AndroidSideloadUpdate],
  /// or null when none is available. Optionally prompts the user to install it.
  Future<AndroidSideloadUpdate?> checkForUpdate({
    bool promptIfAvailable = true,
    AndroidSideloadUpdateCheckSource source =
        AndroidSideloadUpdateCheckSource.manual,
    bool respectStartupThrottle = false,
  }) async {
    if (!isSupportedSideloadBuild) {
      return null;
    }

    appLogger.info(
      'Initiating Android sideload update check (source=${source.name})',
    );
    if (respectStartupThrottle && !_isStartupCheckDue()) {
      appLogger.info(
        'Skipping Android sideload update check due to startup throttle',
      );
      _trackCheckResult(source: source, result: 'skipped_throttled');
      return null;
    }

    if (respectStartupThrottle) {
      await _markStartupCheckAttempted();
    }

    // User-initiated checks show a loading overlay and a result dialog for
    // every outcome; background startup checks stay silent.
    final isManual = source == AndroidSideloadUpdateCheckSource.manual;
    if (isManual) _showLoading();

    appLogger.info(
      'Checking for Android sideload update (source=${source.name})',
    );
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final response = await _fetchUpdate(packageInfo, androidInfo);

      // No payload, or the offered build isn't newer: we're up to date.
      if (response == null ||
          !isAndroidUpdateVersionNewer(response.version, packageInfo.version)) {
        appLogger.info(
          'Android sideload check: already up to date '
          '(current ${packageInfo.version})',
        );
        _trackCheckResult(
          source: source,
          result: response == null ? 'no_update' : 'not_newer',
          version: response?.version,
        );
        if (isManual) {
          _hideLoading();
          _showUpToDateDialog(packageInfo.version);
        }
        return null;
      }

      appLogger.info(
        'Android sideload update available: ${response.version} '
        '(current ${packageInfo.version})',
      );
      _trackCheckResult(
        source: source,
        result: 'update_available',
        version: response.version,
      );
      _trackTelemetry(AndroidSideloadUpdateTelemetryEvent.updateAvailable, {
        'source': source.name,
        'version': response.version,
      });

      // Dismiss the loader before the prompt dialog so they don't overlap.
      if (isManual) _hideLoading();
      if (promptIfAvailable) {
        await _promptUpdate(response, forcePrompt: isManual);
      }
      return response;
    } catch (e) {
      _trackCheckResult(
        source: source,
        result: 'failed',
        error: androidSideloadErrorDescription(e),
      );

      if (isManual) {
        _hideLoading();
        _showCheckFailedDialog();
        return null;
      }
      rethrow;
    }
  }

  /// Posts the current build/device info to the endpoint and parses the
  /// response. Returns null on HTTP 204 (no update available).
  Future<AndroidSideloadUpdate?> _fetchUpdate(
    PackageInfo packageInfo,
    AndroidDeviceInfo androidInfo,
  ) async {
    final body = jsonEncode(
      androidSideloadUpdateRequestBody(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        osVersion: androidInfo.version.release,
        supportedAbis: androidInfo.supportedAbis,
        buildType: AppBuildInfo.buildType,
      ),
    );

    final ownsClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(requestTimeout);

      if (response.statusCode == 204) {
        appLogger.info('No Android sideload update available');
        return null;
      }
      if (response.statusCode != 200) {
        throw HttpException(
          'Android sideload update check failed with '
          '${response.statusCode}: ${response.body}',
          uri: endpoint,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Update response is not a JSON object');
      }
      return AndroidSideloadUpdate.fromJson(decoded);
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Routes an available [update] to the on-screen dialog, falling back to a
  /// notification when no UI context is available. Skips repeat prompts for the
  /// same version unless [forcePrompt] is set.
  Future<void> _promptUpdate(
    AndroidSideloadUpdate update, {
    bool forcePrompt = false,
  }) async {
    if (!forcePrompt && _lastPromptedVersion == update.version) return;
    _lastPromptedVersion = update.version;

    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      await _showUpdateNotification(update);
      return;
    }
    _showUpdateAvailableDialog(update);
  }

  void _showUpdateAvailableDialog(AndroidSideloadUpdate update) {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(
            'update_available'.i18n,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: defaultSize),
          Text(
            'update_ready_to_install'.i18n.fill([update.version]),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'later'.i18n,
          onPressed: () => appRouter.maybePop(),
        ),
        AppTextButton(
          label: 'update_now'.i18n,
          onPressed: () {
            unawaited(() async {
              await appRouter.maybePop();
              await _installUpdate(update);
            }());
          },
        ),
      ],
    );
  }

  void _showUpToDateDialog(String currentVersion) {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.dialog(
      context: context,
      title: 'up_to_date'.i18n,
      content: 'running_latest_version'.i18n.fill([currentVersion]),
    );
  }

  void _showCheckFailedDialog() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.dialog(
      context: context,
      title: 'couldnt_check_for_updates'.i18n,
      content: 'check_connection_and_retry'.i18n,
      action: 'ok'.i18n,
      onPressed: () {
        appRouter.maybePop();
      },
    );
  }

  /// Posts a local notification advertising the available [update].
  Future<void> _showUpdateNotification(AndroidSideloadUpdate update) async {
    if (!sl.isRegistered<NotificationService>()) return;
    await sl<NotificationService>().showNotification(
      id: NotificationEvent.updateAvailable.id,
      title: 'update_available'.i18n,
      body: 'android_sideload_update_available_message'.i18n.fill([
        update.version,
      ]),
      payload: update.url,
    );
  }

  /// Hands the [update] to the platform installer and surfaces the outcome:
  /// a permission dialog, success telemetry, or an error dialog on failure.
  Future<void> _installUpdate(AndroidSideloadUpdate update) async {
    appLogger.info('Installing Android sideload update ${update.version}');
    try {
      final status = await _installer(update);
      if (status == AndroidSideloadInstallStatus.permissionRequired.tag) {
        appLogger.info(
          'Android sideload install needs unknown-sources permission',
        );
        _trackTelemetry(
          AndroidSideloadUpdateTelemetryEvent.installerPermissionRequired,
          {'version': update.version},
        );
        _showInstallPermissionDialog();
        return;
      }
      if (status == AndroidSideloadInstallStatus.installerStarted.tag) {
        appLogger.info(
          'Android sideload installer launched for ${update.version}',
        );
        _trackTelemetry(AndroidSideloadUpdateTelemetryEvent.installerLaunched, {
          'version': update.version,
        });
      }
    } catch (e, st) {
      _trackTelemetry(androidSideloadInstallFailureTelemetryEvent(e), {
        'version': update.version,
        'error': androidSideloadErrorDescription(e),
      });
      appLogger.error('Failed to install Android sideload update', e, st);
      final context = appRouter.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      AppDialog.errorDialog(
        context: context,
        title: 'error_install_update'.i18n,
        content: 'android_sideload_install_failed_message'.i18n,
      );
    }
  }

  /// Prompts the user to grant the "install unknown apps" permission.
  void _showInstallPermissionDialog() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.dialog(
      context: context,
      title: 'allow_unknown_app_installs'.i18n,
      content: 'android_sideload_install_permission_message'.i18n,
    );
  }

  /// Shows the global loading overlay using the active navigator context.
  void _showLoading() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.showLoadingDialog();
  }

  /// Hides the global loading overlay if a navigator context is available.
  void _hideLoading() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    context.hideLoadingDialog();
  }

  /// Whether enough time has passed since the last startup check to run again.
  bool _isStartupCheckDue() {
    return isAndroidSideloadStartupCheckDue(
      now: DateTime.now(),
      lastCheckAt: _storage?.getString(_lastStartupCheckAtKey),
      throttle: startupCheckThrottle,
    );
  }

  /// Records the current time as the last startup check, for throttling.
  Future<void> _markStartupCheckAttempted() async {
    await _storage?.setString(
      _lastStartupCheckAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _trackCheckResult({
    required AndroidSideloadUpdateCheckSource source,
    required String result,
    String? version,
    String? error,
  }) {
    _trackTelemetry(AndroidSideloadUpdateTelemetryEvent.checkResult, {
      'source': source.name,
      'result': result,
      'version': version,
      'error': error,
    });
  }

  LocalStorageService? get _storage =>
      sl.isRegistered<LocalStorageService>() ? sl<LocalStorageService>() : null;

  /// Whether the running app was sideloaded rather than store-installed.
  bool _isSideLoaded() {
    if (!sl.isRegistered<StoreUtils>()) return false;
    return sl<StoreUtils>().isSideLoaded();
  }
}

const _sideloadMethodChannel = MethodChannel('org.getlantern.lantern/method');

/// Invokes the native installer over the method channel, returning its status
/// tag (e.g. `installer_started` or `permission_required`).
Future<String> installSideloadUpdate(AndroidSideloadUpdate update) async {
  final status = await _sideloadMethodChannel.invokeMethod<String>(
    'installSideloadUpdate',
    {'url': update.url, 'checksum': update.checksum, 'version': update.version},
  );
  return status ?? '';
}

/// Returns true when [now] is at least [throttle] past [lastCheckAt]
/// (treating a missing or unparseable timestamp as due).
bool isAndroidSideloadStartupCheckDue({
  required DateTime now,
  required String? lastCheckAt,
  Duration throttle = AndroidSideloadUpdater.startupCheckThrottle,
}) {
  if (lastCheckAt == null || lastCheckAt.trim().isEmpty) return true;
  final previous = DateTime.tryParse(lastCheckAt);
  if (previous == null) return true;
  final elapsed = now.toUtc().difference(previous.toUtc());
  if (elapsed.isNegative) return false;
  return elapsed >= throttle;
}

/// Classifies an install [error] into the matching failure telemetry event
/// (checksum, download, or generic install failure).
AndroidSideloadUpdateTelemetryEvent androidSideloadInstallFailureTelemetryEvent(
  Object error,
) {
  final description = androidSideloadErrorDescription(error).toLowerCase();
  if (description.contains('checksum')) {
    return AndroidSideloadUpdateTelemetryEvent.checksumFailed;
  }
  if (description.contains('download') ||
      description.contains('http') ||
      description.contains('url must use https') ||
      description.contains('unable to create update cache') ||
      description.contains('unable to finalize')) {
    return AndroidSideloadUpdateTelemetryEvent.downloadFailed;
  }
  return AndroidSideloadUpdateTelemetryEvent.installFailed;
}

/// Extracts a human-readable message from an [error], unwrapping
/// [PlatformException]s to their message or code.
String androidSideloadErrorDescription(Object error) {
  if (error is PlatformException) {
    return error.message ?? error.code;
  }
  return error.toString();
}

class AndroidSideloadUpdate {
  AndroidSideloadUpdate({
    required this.url,
    required this.version,
    required this.checksum,
  });

  final String url;
  final String version;
  final String checksum;

  factory AndroidSideloadUpdate.fromJson(Map<String, dynamic> json) {
    String requireNonEmpty(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Update response missing $key');
      }
      return value;
    }

    final patchType = (json['patch_type'] as String?) ?? '';
    if (patchType.isNotEmpty) {
      throw FormatException(
        'Android sideload updates must be full APK downloads, got $patchType',
      );
    }

    final url = requireNonEmpty('url');
    final version = requireNonEmpty('version');
    final checksum = requireNonEmpty('checksum');

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException('Update URL must be HTTPS: $url');
    }

    return AndroidSideloadUpdate(
      url: url,
      version: version,
      checksum: checksum,
    );
  }
}

/// Builds the JSON request body sent to the update endpoint for the current
/// app version, OS, and device ABIs.
Map<String, dynamic> androidSideloadUpdateRequestBody({
  required String appVersion,
  required String buildNumber,
  required String osVersion,
  required List<String> supportedAbis,
  required String buildType,
}) {
  return {
    'version': 1,
    'app_version': appVersion,
    'os_version': osVersion,
    'checksum': '',
    'tags': {
      'os': 'android',
      'arch': androidUpdateArchForAbis(supportedAbis),
      'channel': androidUpdateChannelForBuildType(buildType),
      'build_type': buildType,
      'build_number': buildNumber,
      'installer_source': 'sideload',
    },
  };
}

/// Maps the device's [supportedAbis] to the update arch tag (`arm64` or `arm`).
String androidUpdateArchForAbis(List<String> supportedAbis) {
  final normalized = supportedAbis.map((abi) => abi.toLowerCase()).toSet();
  if (normalized.contains('arm64-v8a')) return 'arm64';
  return 'arm';
}

/// Maps a [buildType] to its release channel (`beta`, `nightly`, or `stable`).
String androidUpdateChannelForBuildType(String buildType) {
  switch (buildType.toLowerCase()) {
    case 'beta':
      return 'beta';
    case 'nightly':
    case 'internal':
    case 'dev':
    case 'development':
      return 'nightly';
    default:
      return 'stable';
  }
}

/// Whether [candidate] is a strictly newer semver than [current]
/// (returns false if either version fails to parse).
bool isAndroidUpdateVersionNewer(String candidate, String current) {
  final candidateVersion = _tryParseVersion(candidate);
  final currentVersion = _tryParseVersion(current);
  if (candidateVersion == null || currentVersion == null) return false;
  return candidateVersion > currentVersion;
}

/// Parses [input] as a semver, stripping a leading `v`; null on failure.
Version? _tryParseVersion(String input) {
  var normalized = input.trim();
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1);
  }
  try {
    return Version.parse(normalized);
  } on FormatException {
    return null;
  }
}
