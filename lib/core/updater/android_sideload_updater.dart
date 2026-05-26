import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/models/notification_event.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/core/utils/store_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

const androidSideloadUpdateEndpoint =
    'https://update.getlantern.org/update/lantern';

typedef PackageInfoProvider = Future<PackageInfo> Function();
typedef AndroidInfoProvider = Future<AndroidDeviceInfo> Function();
typedef HttpClientProvider = HttpClient Function();
typedef DateTimeProvider = DateTime Function();

enum AndroidSideloadUpdateCheckSource { startup, manual }

class AndroidSideloadUpdateTelemetryEvent {
  static const checkResult = 'android_sideload_update_check_result';
  static const updateAvailable = 'android_sideload_update_available';
  static const downloadFailed = 'android_sideload_update_download_failed';
  static const checksumFailed = 'android_sideload_update_checksum_failed';
  static const installerLaunched = 'android_sideload_update_installer_launched';
  static const installerPermissionRequired =
      'android_sideload_update_installer_permission_required';
  static const installFailed = 'android_sideload_update_install_failed';
}

class AndroidSideloadUpdateTelemetry {
  const AndroidSideloadUpdateTelemetry();

  void track(String event, Map<String, Object?> properties) {
    final sanitized = <String, Object?>{
      for (final entry in properties.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    appLogger.info(
      'telemetry event=$event properties=${jsonEncode(sanitized)}',
    );
  }
}

class AndroidSideloadUpdater {
  AndroidSideloadUpdater({
    Uri? endpoint,
    PackageInfoProvider? packageInfoProvider,
    AndroidInfoProvider? androidInfoProvider,
    HttpClientProvider? httpClientProvider,
    StoreUtils? storeUtils,
    AndroidSideloadInstallerBridge? installerBridge,
    LocalStorageService? localStorageService,
    AndroidSideloadUpdateTelemetry? telemetry,
    DateTimeProvider? clock,
  }) : endpoint = endpoint ?? Uri.parse(androidSideloadUpdateEndpoint),
       _packageInfoProvider = packageInfoProvider ?? PackageInfo.fromPlatform,
       _androidInfoProvider =
           androidInfoProvider ?? (() => DeviceInfoPlugin().androidInfo),
       _httpClientProvider = httpClientProvider ?? HttpClient.new,
       _storeUtils = storeUtils,
       _localStorageService = localStorageService,
       _installerBridge =
           installerBridge ?? const AndroidSideloadInstallerBridge(),
       _telemetry = telemetry ?? const AndroidSideloadUpdateTelemetry(),
       _clock = clock ?? DateTime.now;

  static const firstPromptDelay = Duration(seconds: 45);
  static const startupCheckThrottle = Duration(days: 1);
  static const requestTimeout = Duration(seconds: 20);
  static const _lastStartupCheckAtKey =
      'android_sideload_update_last_startup_check_at';

  final Uri endpoint;
  final PackageInfoProvider _packageInfoProvider;
  final AndroidInfoProvider _androidInfoProvider;
  final HttpClientProvider _httpClientProvider;
  final StoreUtils? _storeUtils;
  final LocalStorageService? _localStorageService;
  final AndroidSideloadInstallerBridge _installerBridge;
  final AndroidSideloadUpdateTelemetry _telemetry;
  final DateTimeProvider _clock;

  bool _initialized = false;
  String? _lastPromptedVersion;

  Future<void> init(Map<String, dynamic> flags) async {
    if (_initialized) return;
    _initialized = true;

    if (!isEnabled(flags)) return;

    unawaited(
      Future<void>.delayed(firstPromptDelay, () async {
        try {
          await checkNow(
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

  bool isEnabled(Map<String, dynamic> flags, {bool logDisabled = true}) {
    if (!isSupportedSideloadBuild) return false;
    if (!flags.getBool(FeatureFlag.autoUpdateEnabled, defaultValue: true)) {
      if (logDisabled) {
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
      if (logDisabled) {
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

  Future<AndroidSideloadUpdate?> checkNow({
    bool promptIfAvailable = true,
    AndroidSideloadUpdateCheckSource source =
        AndroidSideloadUpdateCheckSource.manual,
    bool respectStartupThrottle = false,
  }) async {
    if (!isSupportedSideloadBuild) {
      return null;
    }

    if (respectStartupThrottle && !_isStartupCheckDue()) {
      _trackCheckResult(source: source, result: 'skipped_throttled');
      return null;
    }

    if (respectStartupThrottle) {
      await _markStartupCheckAttempted();
    }

    try {
      final packageInfo = await _packageInfoProvider();
      final androidInfo = await _androidInfoProvider();
      final response = await _requestUpdate(packageInfo, androidInfo);
      if (response == null) {
        _trackCheckResult(source: source, result: 'no_update');
        return null;
      }
      if (!isAndroidUpdateVersionNewer(response.version, packageInfo.version)) {
        appLogger.info(
          'Ignoring Android sideload update ${response.version}; '
          'current version is ${packageInfo.version}',
        );
        _trackCheckResult(
          source: source,
          result: 'not_newer',
          version: response.version,
        );
        return null;
      }

      _trackCheckResult(
        source: source,
        result: 'update_available',
        version: response.version,
      );
      _telemetry.track(AndroidSideloadUpdateTelemetryEvent.updateAvailable, {
        'source': source.name,
        'version': response.version,
      });

      if (promptIfAvailable) {
        await _promptUpdate(
          response,
          forcePrompt: source == AndroidSideloadUpdateCheckSource.manual,
        );
      }
      return response;
    } catch (e) {
      _trackCheckResult(
        source: source,
        result: 'failed',
        error: androidSideloadErrorDescription(e),
      );
      rethrow;
    }
  }

  Future<AndroidSideloadUpdate?> _requestUpdate(
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

    final client = _httpClientProvider();
    try {
      final request = await client.postUrl(endpoint).timeout(requestTimeout);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      request.write(body);

      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode == HttpStatus.noContent) {
        appLogger.info('No Android sideload update available');
        return null;
      }
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Android sideload update check failed with '
          '${response.statusCode}: $responseBody',
          uri: endpoint,
        );
      }
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Update response is not a JSON object');
      }
      return AndroidSideloadUpdate.fromJson(decoded);
    } finally {
      client.close(force: true);
    }
  }

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
            'android_sideload_update_available_message'.i18n.fill([
              update.version,
            ]),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'not_now'.i18n,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        AppTextButton(
          label: 'download_and_install_update'.i18n,
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

  Future<void> _installUpdate(AndroidSideloadUpdate update) async {
    try {
      final status = await _installerBridge.install(update);
      if (status == AndroidSideloadInstallerBridge.permissionRequired) {
        _telemetry.track(
          AndroidSideloadUpdateTelemetryEvent.installerPermissionRequired,
          {'version': update.version},
        );
        _showInstallPermissionDialog();
        return;
      }
      if (status == AndroidSideloadInstallerBridge.installerStarted) {
        _telemetry.track(
          AndroidSideloadUpdateTelemetryEvent.installerLaunched,
          {'version': update.version},
        );
      }
    } catch (e, st) {
      _telemetry.track(androidSideloadInstallFailureTelemetryEvent(e), {
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

  void _showInstallPermissionDialog() {
    final context = appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    AppDialog.dialog(
      context: context,
      title: 'allow_unknown_app_installs'.i18n,
      content: 'android_sideload_install_permission_message'.i18n,
    );
  }

  bool _isStartupCheckDue() {
    return isAndroidSideloadStartupCheckDue(
      now: _clock(),
      lastCheckAt: _storage?.getString(_lastStartupCheckAtKey),
      throttle: startupCheckThrottle,
    );
  }

  Future<void> _markStartupCheckAttempted() async {
    await _storage?.setString(
      _lastStartupCheckAtKey,
      _clock().toUtc().toIso8601String(),
    );
  }

  void _trackCheckResult({
    required AndroidSideloadUpdateCheckSource source,
    required String result,
    String? version,
    String? error,
  }) {
    _telemetry.track(AndroidSideloadUpdateTelemetryEvent.checkResult, {
      'source': source.name,
      'result': result,
      'version': version,
      'error': error,
    });
  }

  LocalStorageService? get _storage {
    return _localStorageService ??
        (sl.isRegistered<LocalStorageService>()
            ? sl<LocalStorageService>()
            : null);
  }

  bool _isSideLoaded() {
    final storeUtils =
        _storeUtils ??
        (sl.isRegistered<StoreUtils>() ? sl<StoreUtils>() : null);
    return storeUtils?.isSideLoaded() ?? false;
  }
}

class AndroidSideloadInstallerBridge {
  const AndroidSideloadInstallerBridge();

  static const installerStarted = 'installer_started';
  static const permissionRequired = 'permission_required';
  static const MethodChannel _methodChannel = MethodChannel(
    'org.getlantern.lantern/method',
  );

  Future<String> install(AndroidSideloadUpdate update) async {
    final status = await _methodChannel.invokeMethod<String>(
      'installSideloadUpdate',
      {
        'url': update.url,
        'checksum': update.checksum,
        'version': update.version,
      },
    );
    return status ?? '';
  }
}

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

String androidSideloadInstallFailureTelemetryEvent(Object error) {
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
    final patchType = (json['patch_type'] as String?) ?? '';
    if (patchType.isNotEmpty) {
      throw FormatException(
        'Android sideload updates must be full APK downloads, got $patchType',
      );
    }

    final url = json['url'];
    final version = json['version'];
    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('Update response missing URL');
    }
    if (version is! String || version.trim().isEmpty) {
      throw const FormatException('Update response missing version');
    }
    final checksum = json['checksum'];
    if (checksum is! String || checksum.trim().isEmpty) {
      throw const FormatException('Update response missing checksum');
    }

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

String androidUpdateArchForAbis(List<String> supportedAbis) {
  final normalized = supportedAbis.map((abi) => abi.toLowerCase()).toSet();
  if (normalized.contains('arm64-v8a')) return 'arm64';
  return 'arm';
}

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

bool isAndroidUpdateVersionNewer(String candidate, String current) {
  final candidateVersion = _ComparableVersion.tryParse(candidate);
  final currentVersion = _ComparableVersion.tryParse(current);
  if (candidateVersion == null || currentVersion == null) {
    return false;
  }
  return candidateVersion.compareTo(currentVersion) > 0;
}

class _ComparableVersion implements Comparable<_ComparableVersion> {
  _ComparableVersion(this.major, this.minor, this.patch, this.prerelease);

  final int major;
  final int minor;
  final int patch;
  final List<String> prerelease;

  static _ComparableVersion? tryParse(String input) {
    var normalized = input.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    normalized = normalized.split('+').first;
    final parts = normalized.split('-');
    final coreParts = parts.first.split('.');
    if (coreParts.isEmpty || coreParts.length > 3) return null;

    int parsePart(int index) {
      if (index >= coreParts.length) return 0;
      return int.parse(coreParts[index]);
    }

    try {
      return _ComparableVersion(
        parsePart(0),
        parsePart(1),
        parsePart(2),
        parts.length > 1 ? parts.sublist(1).join('-').split('.') : const [],
      );
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(_ComparableVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final comparison = pair.$1.compareTo(pair.$2);
      if (comparison != 0) return comparison;
    }

    if (prerelease.isEmpty && other.prerelease.isNotEmpty) return 1;
    if (prerelease.isNotEmpty && other.prerelease.isEmpty) return -1;

    final maxLength = prerelease.length > other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var i = 0; i < maxLength; i++) {
      if (i >= prerelease.length) return -1;
      if (i >= other.prerelease.length) return 1;
      final comparison = _comparePrereleasePart(
        prerelease[i],
        other.prerelease[i],
      );
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static int _comparePrereleasePart(String a, String b) {
    final aNum = int.tryParse(a);
    final bNum = int.tryParse(b);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);
    if (aNum != null) return -1;
    if (bNum != null) return 1;
    return a.compareTo(b);
  }
}
