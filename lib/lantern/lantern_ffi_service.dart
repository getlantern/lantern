import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart' hide DeveloperMode;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/utils/app_data_utils.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/windows/pipe_client.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_windows_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';
import 'package:path/path.dart' as p;

import '../core/models/available_servers.dart';
import '../core/models/macos_extension_state.dart';
import '../core/models/plan_data.dart';
import '../core/utils/compute_worker.dart';

export 'dart:convert';
export 'dart:ffi'; // For FFI

export 'package:ffi/src/utf8.dart';

const String _libName = 'liblantern';
const Set<String> _ffiOkResults = {'ok', 'true'};

/// Communicates with the native library via FFI.
///
/// This is meant to be used only by [LanternService].
class LanternFFIService implements LanternCoreService {
  static final LanternBindings _ffiService = _gen();
  static const String _windowsServiceName = 'LanternSvc';

  /// Windows IPC is optional. If it fails to init (missing token, timeout, etc),
  /// we keep going and fall back to the non-IPC paths.
  LanternServiceWindows? _windowsService;
  Future<LanternServiceWindows?>? _windowsServiceInitInFlight;
  DateTime? _windowsServiceLastInitFailureAt;
  String? _windowsServiceLastInitFailureMessage;
  static const Duration _windowsServiceRetryCooldown = Duration(seconds: 15);
  static const Duration _windowsServiceStartWait = Duration(seconds: 6);
  static const Duration _windowsServicePollInterval = Duration(
    milliseconds: 300,
  );
  static const Duration _windowsInitRetryInterval = Duration(seconds: 3);
  static const int _windowsWarmupMaxAttempts = 8;
  static const Duration _windowsWarmupMaxDelay = Duration(seconds: 30);
  StreamSubscription<LanternStatus>? _windowsStatusSubscription;
  LanternStatus _lastWindowsStatus = LanternStatus.fromJson({
    'status': 'disconnected',
    'error': null,
  });
  final StreamController<LanternStatus> _windowsStatusController =
      StreamController<LanternStatus>.broadcast();

  Stream<LanternStatus> _status = _defaultStatusStream();

  Stream<PrivateServerStatus> _privateServerStatus =
      const Stream<PrivateServerStatus>.empty();
  Stream<AppEvent> _appEvents = const Stream<AppEvent>.empty();
  static const Duration _appsCacheMaxAge = Duration(hours: 6);
  static const Duration _appsCatalogRefreshInterval = Duration(minutes: 5);
  Future<List<AppData>>? _appsScanInFlight;
  List<AppData> _lastAppsSnapshot = const <AppData>[];
  DateTime? _lastAppsScanAt;

  static Stream<LanternStatus> _defaultStatusStream() {
    // Keep a predictable default (matches the Windows status mapping behavior).
    return Stream<LanternStatus>.value(
      LanternStatus.fromJson({'status': 'disconnected', 'error': null}),
    );
  }

  static SendPort? _commandSendPort;
  static final Completer<void> _isolateInitialized = Completer<void>();

  // Receive ports for different app services
  static final commandReceivePort = ReceivePort();
  static final statusReceivePort = ReceivePort();
  static final privateServerReceivePort = ReceivePort();
  static final appsReceivePort = ReceivePort();
  static final loggingReceivePort = ReceivePort();
  static final flutterEventReceivePort = ReceivePort();

  static LanternBindings _gen() {
    final String basePath = p.dirname(Platform.resolvedExecutable);
    final String fullPath;
    appLogger.debug('resolved executable: "${Platform.resolvedExecutable}"');

    if (Platform.isWindows) {
      final candidates = <String>[
        p.join(basePath, "$_libName.dll"),
        p.join(basePath, "bin", "$_libName.dll"),
        p.join(basePath, "bin", "windows", "$_libName.dll"),
      ];
      fullPath = _firstExisting(candidates);
    } else if (Platform.isLinux) {
      final envPath = Platform.environment['LANTERN_LIB_PATH'];
      final candidates = <String>[
        if (envPath != null && envPath.isNotEmpty) envPath,
        p.join(basePath, "$_libName.so"),
        p.join(basePath, "lib", "$_libName.so"),
        "/usr/lib/lantern/$_libName.so",
      ];
      fullPath = _firstExisting(candidates);
    } else {
      fullPath = p.join(basePath, "$_libName.so");
    }

    appLogger.debug('singbox native libs path: "$fullPath"');
    final lib = DynamicLibrary.open(fullPath);
    return LanternBindings(lib);
  }

  static String _firstExisting(List<String> candidates) {
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    appLogger.warning(
      'Native library not found in candidates: ${candidates.join(', ')}',
    );
    return candidates.first;
  }

  @override
  Future<void> init() async {
    // Set safe defaults up front so callers always have something to listen to.
    _status = _defaultStatusStream();
    _privateServerStatus = const Stream<PrivateServerStatus>.empty();
    _appEvents = const Stream<AppEvent>.empty();

    try {
      final setupResult = await _setupRadiance();
      setupResult.fold((err) {
        appLogger.error('Radiance setup failed: $err');
      }, (_) {});

      if (Platform.isWindows) {
        // Keep startup responsive. IPC warmup runs in the background.
        unawaited(_startWindowsServiceWarmup());

        if (!_isolateInitialized.isCompleted) {
          await _initializeCommandIsolate();
        }
      } else {
        _status = statusReceivePort.map((event) {
          final Map<String, dynamic> result = jsonDecode(event);
          return LanternStatus.fromJson(result);
        });
      }

      // These streams exist even if Windows IPC doesn't.
      _privateServerStatus = privateServerReceivePort.map((event) {
        final Map<String, dynamic> result = jsonDecode(event);
        return PrivateServerStatus.fromJson(result);
      });

      _appEvents = flutterEventReceivePort.map((event) {
        final Map<String, dynamic> result = jsonDecode(event);
        return AppEvent.fromJson(result);
      });

      if (Platform.isWindows) {
        unawaited(_primeAppsCatalog());
      }
    } catch (e, st) {
      appLogger.error('Error while setting up radiance', e, st);
    }
  }

  /// Determine the appropriate environment string for Radiance based on build mode and stage detection.
  Future<String> _radianceEnv() async {
    if (kReleaseMode) {
      return "prod";
    } else {
      final isStageFound = await isStageEnvironment();
      return isStageFound ? "stage" : "prod";
    }
  }

  Future<Either<String, Unit>> _setupRadiance() async {
    try {
      appLogger.debug('Setting up radiance');
      int consent = 0;
      String env = await _radianceEnv();
      try {
        // Telemetry consent can be forwarded here when needed.
      } catch (_) {
        appLogger.warning(
          'No app setting found, defaulting telemetry consent to false',
        );
      }

      final dataDir = await AppStorageUtils.getAppDirectory();
      final logDir = await AppStorageUtils.getAppLogDirectory();
      appLogger.info(
        "Radiance configuration - env: $env, dataDir: ${dataDir.path}, logDir: $logDir, telemetryConsent: $consent",
      );

      final dataDirPtr = dataDir.path.toCharPtr;
      final logDirPtr = logDir.toCharPtr;

      // setup() must run on the main isolate.
      // It wires up the Dart <-> Go bridge using NativeApi.initializeApiDLData.
      // Running it from a background isolate will break the Dart DL bridge.
      final result = _ffiService
          .setup(
            logDirPtr,
            dataDirPtr,
            Localization.defaultLocale.toCharPtr,
            env.toCharPtr,
            loggingReceivePort.sendPort.nativePort,
            appsReceivePort.sendPort.nativePort,
            statusReceivePort.sendPort.nativePort,
            privateServerReceivePort.sendPort.nativePort,
            flutterEventReceivePort.sendPort.nativePort,
            consent,
            NativeApi.initializeApiDLData,
          )
          .toDartString();

      checkAPIError(result);
      if (result != 'ok' && result != 'true') {
        throw PlatformException(code: 'radiance_setup_failed', message: result);
      }
      return right(unit);
    } catch (e, st) {
      appLogger.error('Failed to set up radiance: $e', e, st);
      return Left(e.toFailure().localizedErrorMessage);
    }
  }

  Stream<LanternStatus> _watchWindowsStatus() async* {
    yield _lastWindowsStatus;
    yield* _windowsStatusController.stream;
  }

  void _publishWindowsStatus(LanternStatus status) {
    _lastWindowsStatus = status;
    if (!_windowsStatusController.isClosed) {
      _windowsStatusController.add(status);
    }
  }

  Future<void> _attachWindowsStatusStream(
    LanternServiceWindows windowsService,
  ) async {
    final previous = _windowsStatusSubscription;
    _windowsStatusSubscription = null;
    if (previous != null) {
      await previous.cancel();
    }
    _windowsStatusSubscription = windowsService.watchVPNStatus().listen(
      _publishWindowsStatus,
      onError: (Object error, StackTrace stackTrace) {
        appLogger.error('Windows status stream failed', error, stackTrace);
      },
    );
  }

  Future<void> _startWindowsServiceWarmup() async {
    var retryDelay = _windowsInitRetryInterval;
    for (
      var attempt = 1;
      Platform.isWindows && attempt <= _windowsWarmupMaxAttempts;
      attempt++
    ) {
      final windowsService = await _getOrInitWindowsService(forceRetry: true);
      if (windowsService != null) {
        return;
      }

      final serviceState = await _readWindowsServiceState();
      if (serviceState == _WindowsServiceState.missing) {
        appLogger.warning(
          'Windows IPC warmup stopped: service $_windowsServiceName is missing',
        );
        return;
      }

      if (attempt == _windowsWarmupMaxAttempts) {
        appLogger.warning(
          'Windows IPC warmup did not complete after '
          '$_windowsWarmupMaxAttempts attempts; stopping warmup',
        );
        return;
      }

      appLogger.warning(
        'Windows IPC warmup did not complete; retrying in '
        '${retryDelay.inMilliseconds}ms '
        '(attempt $attempt of $_windowsWarmupMaxAttempts)',
      );
      await Future.delayed(retryDelay);
      retryDelay = _nextWarmupRetryDelay(retryDelay);
    }
  }

  Duration _nextWarmupRetryDelay(Duration current) {
    final doubledMs = current.inMilliseconds * 2;
    final maxMs = _windowsWarmupMaxDelay.inMilliseconds;
    final nextMs = doubledMs > maxMs ? maxMs : doubledMs;
    return Duration(milliseconds: nextMs);
  }

  Future<_WindowsServiceState> _readWindowsServiceState() async {
    try {
      final result = await Process.run('sc.exe', [
        'query',
        _windowsServiceName,
      ]);
      final text = '${result.stdout}\n${result.stderr}'.toUpperCase();
      if (result.exitCode == 1060 ||
          text.contains('FAILED 1060') ||
          text.contains('DOES NOT EXIST')) {
        return _WindowsServiceState.missing;
      }
      if (text.contains('STATE') && text.contains('START_PENDING')) {
        return _WindowsServiceState.startPending;
      }
      if (text.contains('STATE') && text.contains('STOP_PENDING')) {
        return _WindowsServiceState.stopPending;
      }
      if (text.contains('STATE') && text.contains('RUNNING')) {
        return _WindowsServiceState.running;
      }
      if (text.contains('STATE') && text.contains('STOPPED')) {
        return _WindowsServiceState.stopped;
      }
      return result.exitCode == 0
          ? _WindowsServiceState.stopped
          : _WindowsServiceState.unknown;
    } catch (e, st) {
      appLogger.error('Failed to query Windows service state', e, st);
      return _WindowsServiceState.unknown;
    }
  }

  Future<bool> _waitForWindowsServiceRunning(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await _readWindowsServiceState();
      switch (state) {
        case _WindowsServiceState.running:
          return true;
        case _WindowsServiceState.missing:
          return false;
        case _WindowsServiceState.startPending:
        case _WindowsServiceState.stopPending:
        case _WindowsServiceState.stopped:
        case _WindowsServiceState.unknown:
          break;
      }
      await Future.delayed(_windowsServicePollInterval);
    }
    return false;
  }

  Future<bool> _waitForWindowsServiceStopped(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await _readWindowsServiceState();
      switch (state) {
        case _WindowsServiceState.stopped:
          return true;
        case _WindowsServiceState.missing:
          return false;
        case _WindowsServiceState.startPending:
        case _WindowsServiceState.stopPending:
        case _WindowsServiceState.running:
        case _WindowsServiceState.unknown:
          break;
      }
      await Future.delayed(_windowsServicePollInterval);
    }
    return false;
  }

  Future<bool> _prepareWindowsService() async {
    final state = await _readWindowsServiceState();
    switch (state) {
      case _WindowsServiceState.running:
        return true;
      case _WindowsServiceState.missing:
        _windowsServiceLastInitFailureMessage =
            'Windows service LanternSvc is missing.';
        return false;
      case _WindowsServiceState.startPending:
        final running = await _waitForWindowsServiceRunning(
          _windowsServiceStartWait,
        );
        if (!running) {
          _windowsServiceLastInitFailureMessage =
              'Windows service LanternSvc did not reach running state.';
        }
        return running;
      case _WindowsServiceState.stopped:
      case _WindowsServiceState.stopPending:
        try {
          if (state == _WindowsServiceState.stopPending) {
            final stopped = await _waitForWindowsServiceStopped(
              _windowsServiceStartWait,
            );
            if (!stopped) {
              _windowsServiceLastInitFailureMessage =
                  'Windows service LanternSvc did not reach stopped state.';
              return false;
            }
          }
          final startResult = await Process.run('sc.exe', [
            'start',
            _windowsServiceName,
          ]);
          if (startResult.exitCode != 0) {
            _windowsServiceLastInitFailureMessage =
                'Windows service LanternSvc could not start.';
            appLogger.warning(
              'Failed to start Windows service',
              startResult.stdout,
              StackTrace.current,
            );
            return false;
          }
          final running = await _waitForWindowsServiceRunning(
            _windowsServiceStartWait,
          );
          if (!running) {
            _windowsServiceLastInitFailureMessage =
                'Windows service LanternSvc did not reach running state.';
          }
          return running;
        } catch (e, st) {
          _windowsServiceLastInitFailureMessage =
              'Windows service LanternSvc start command failed.';
          appLogger.error('Failed to start Windows service', e, st);
          return false;
        }
      case _WindowsServiceState.unknown:
        appLogger.warning(
          'Windows service state is unknown; proceeding with IPC attempt',
        );
        return true;
    }
  }

  String _describeWindowsIpcFailure(Object error) {
    if (error is PipeTokenException) {
      return switch (error.kind) {
        PipeTokenErrorKind.missing =>
          'IPC token file is missing at ${error.path}.',
        PipeTokenErrorKind.empty => 'IPC token file is empty at ${error.path}.',
        PipeTokenErrorKind.unreadable =>
          'IPC token file could not be read at ${error.path}.',
      };
    }
    if (error is PipeTransportException) {
      if (error.timedOut) {
        return 'Windows IPC pipe open timed out.';
      }
      return 'Windows IPC transport failed (${error.code}).';
    }
    return error.toString();
  }

  String _windowsIpcUnavailableMessage() {
    final details = _windowsServiceLastInitFailureMessage;
    if (details == null || details.trim().isEmpty) {
      return 'The Windows VPN service did not initialize (IPC unavailable).';
    }
    return 'The Windows VPN service is unavailable: $details';
  }

  Future<void> _initializeWindowsService() async {
    final tokenPath = p.join(
      Platform.environment['ProgramData'] ?? r'C:\ProgramData',
      'Lantern',
      'ipc-token',
    );
    final pipe = PipeClient(
      tokenPath: tokenPath,
      timeoutMs: 1500,
      tokenWaitMs: 1500,
    );

    // Create locally first; only assign to the field after init succeeds.
    final ws = LanternServiceWindows(pipe);

    try {
      await ws.init();
      _windowsService = ws;
      _windowsServiceLastInitFailureAt = null;
      _windowsServiceLastInitFailureMessage = null;
      await _attachWindowsStatusStream(ws);
    } catch (e, st) {
      appLogger.error('LanternServiceWindows.init() threw', e, st);
      _windowsService = null;
      rethrow; // init() will catch and keep going; this keeps the original stack.
    }
  }

  Future<LanternServiceWindows?> _getOrInitWindowsService({
    bool forceRetry = false,
  }) async {
    final existing = _windowsService;
    if (existing != null) {
      return existing;
    }

    if (!forceRetry) {
      final lastFailureAt = _windowsServiceLastInitFailureAt;
      if (lastFailureAt != null &&
          DateTime.now().difference(lastFailureAt) <
              _windowsServiceRetryCooldown) {
        return null;
      }
    }

    final inFlight = _windowsServiceInitInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final initFuture = () async {
      try {
        final ready = await _prepareWindowsService();
        if (!ready) {
          _windowsService = null;
          _windowsServiceLastInitFailureAt = DateTime.now();
          return null;
        }
        await _initializeWindowsService();
      } catch (e, st) {
        appLogger.error('Windows IPC re-init failed', e, st);
        _windowsService = null;
        _windowsServiceLastInitFailureAt = DateTime.now();
        _windowsServiceLastInitFailureMessage = _describeWindowsIpcFailure(e);
      } finally {
        _windowsServiceInitInFlight = null;
      }
      return _windowsService;
    }();

    _windowsServiceInitInFlight = initFuture;
    return initFuture;
  }

  Future<void> _markWindowsStatusOrigin(VPNStatusOrigin origin) async {
    if (!Platform.isWindows) {
      return;
    }
    final ws = await _getOrInitWindowsService();
    ws?.setNextStatusOrigin(origin);
  }

  @override
  Stream<AppEvent> watchAppEvents() {
    return _appEvents;
  }

  @override
  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .updateTelemetryConsent(consent ? 1 : 0)
            .toDartString();
      });
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('Error updating telemetry events', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setRoutingMode(bool mode) async {
    try {
      await _markWindowsStatusOrigin(VPNStatusOrigin.settingsMutation);
      final result = await runInBackground<String>(() async {
        return _ffiService.setSmartRoutingEnabled(mode ? 1 : 0).toDartString();
      });

      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('Error setting routing mode via FFI', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    final String dataDir = _ffiService.getAppDataDir().toDartString();
    final enabledKeys = await _getEnabledAppKeys();
    var latestEmitted = const <AppData>[];

    final memoryApps = _appsFromSnapshot(enabledKeys);
    if (memoryApps.isNotEmpty) {
      yield memoryApps;
      latestEmitted = memoryApps;
    }

    final cachedApps = await _loadCachedApps(dataDir, enabledKeys);
    if (cachedApps.isNotEmpty && memoryApps.isEmpty) {
      appLogger.debug(
        'Loaded ${cachedApps.length} apps from cache before full scan',
      );
      yield cachedApps;
      latestEmitted = cachedApps;
    }

    final hasImmediateApps = memoryApps.isNotEmpty || cachedApps.isNotEmpty;
    if (hasImmediateApps) {
      try {
        final scannedApps = await _scanInstalledApps(dataDir, enabledKeys);
        if (_appsSnapshotChanged(latestEmitted, scannedApps)) {
          yield scannedApps;
        }
      } catch (e, st) {
        appLogger.error("Failed to refresh installed apps", e, st);
      }
      return;
    }

    try {
      final scannedApps = await _scanInstalledApps(dataDir, enabledKeys);
      if (scannedApps.isEmpty && cachedApps.isEmpty && memoryApps.isEmpty) {
        yield [];
        return;
      }
      yield scannedApps;
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      if (cachedApps.isEmpty && memoryApps.isEmpty) {
        yield [];
      }
    }
  }

  @override
  Future<Uint8List?> loadInstalledAppIconBytes({
    required String appPath,
    required String iconPath,
  }) async {
    final normalizedAppPath = appPath.trim();
    final normalizedIconPath = iconPath.trim();
    if (normalizedAppPath.isEmpty && normalizedIconPath.isEmpty) {
      return null;
    }

    try {
      final encoded = await runInBackground<String>(() async {
        final appPathPtr = normalizedAppPath.toNativeUtf8();
        final iconPathPtr = normalizedIconPath.toNativeUtf8();
        try {
          return _ffiService
              .loadInstalledAppIcon(
                appPathPtr.cast<Char>(),
                iconPathPtr.cast<Char>(),
              )
              .toDartString();
        } finally {
          malloc.free(appPathPtr);
          malloc.free(iconPathPtr);
        }
      });

      final trimmed = encoded.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      if (trimmed.startsWith('{') && trimmed.contains('"error"')) {
        checkAPIError(trimmed);
        return null;
      }
      return base64Decode(trimmed);
    } catch (e, st) {
      appLogger.error('Failed to load installed app icon bytes', e, st);
      return null;
    }
  }

  List<AppData> _appsFromSnapshot(Set<String> enabledKeys) {
    if (_lastAppsSnapshot.isEmpty) {
      return const <AppData>[];
    }
    return _applyEnabledState(_lastAppsSnapshot, enabledKeys);
  }

  bool _appsSnapshotChanged(List<AppData> previous, List<AppData> next) {
    if (previous.length != next.length) {
      return true;
    }

    final previousFingerprints = previous.map(_appFingerprint).toList()..sort();
    final nextFingerprints = next.map(_appFingerprint).toList()..sort();
    for (var i = 0; i < previousFingerprints.length; i++) {
      if (previousFingerprints[i] != nextFingerprints[i]) {
        return true;
      }
    }

    return false;
  }

  String _appFingerprint(AppData app) {
    return [
      _normalizeSplitTunnelKey(app.bundleId),
      _normalizeSplitTunnelKey(app.appPath),
      _normalizeSplitTunnelKey(app.iconPath),
      app.name.trim().toLowerCase(),
      app.isEnabled ? '1' : '0',
      app.removed ? '1' : '0',
    ].join('|');
  }

  Future<void> _primeAppsCatalog() async {
    final dataDir = _ffiService.getAppDataDir().toDartString();
    if (_isAppsCatalogFresh()) {
      return;
    }
    try {
      await _scanInstalledApps(dataDir, const <String>{});
    } catch (e, st) {
      appLogger.error('Failed to prewarm apps catalog', e, st);
    }
  }

  bool _isAppsCatalogFresh() {
    final last = _lastAppsScanAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) <= _appsCatalogRefreshInterval;
  }

  Future<List<AppData>> _scanInstalledApps(
    String dataDir,
    Set<String> enabledKeys,
  ) async {
    final inFlight = _appsScanInFlight;
    if (inFlight != null) {
      final snapshot = await inFlight;
      return _applyEnabledState(snapshot, enabledKeys);
    }

    final scanFuture = _scanInstalledAppsRaw(dataDir);
    _appsScanInFlight = scanFuture;
    try {
      final snapshot = await scanFuture;
      _lastAppsSnapshot = snapshot
          .map((app) => app.copyWith(isEnabled: false))
          .toList();
      _lastAppsScanAt = DateTime.now();
      return _applyEnabledState(snapshot, enabledKeys);
    } finally {
      _appsScanInFlight = null;
    }
  }

  Future<List<AppData>> _scanInstalledAppsRaw(String dataDir) async {
    final String jsonApps = await runInBackground<String>(() async {
      final ptr = dataDir.toNativeUtf8();
      try {
        return _ffiService.loadInstalledApps(ptr.cast<Char>()).toDartString();
      } finally {
        malloc.free(ptr);
      }
    });

    checkAPIError(jsonApps);
    if (jsonApps.isEmpty) {
      return const <AppData>[];
    }
    return _parseAppsJson(jsonApps);
  }

  Future<Set<String>> _getEnabledAppKeys() async {
    try {
      final enabledJson = await runInBackground<String>(() async {
        return _ffiService.getEnabledApps().toDartString();
      });
      checkAPIError(enabledJson);
      final dynamic decoded = jsonDecode(enabledJson);
      if (decoded is! List) {
        return const <String>{};
      }
      return decoded
          .map((item) => _normalizeSplitTunnelKey(item?.toString() ?? ''))
          .where((item) => item.isNotEmpty)
          .toSet();
    } catch (e, st) {
      appLogger.error('Failed to load enabled split-tunnel apps', e, st);
      return const <String>{};
    }
  }

  Future<List<AppData>> _loadCachedApps(
    String dataDir,
    Set<String> enabledKeys,
  ) async {
    try {
      final cachePath = p.join(dataDir, 'apps_cache.json');
      final file = File(cachePath);
      if (!file.existsSync()) {
        return const <AppData>[];
      }
      final stats = await file.stat();
      if (DateTime.now().difference(stats.modified) > _appsCacheMaxAge) {
        appLogger.debug('Skipping stale apps cache at $cachePath');
        return const <AppData>[];
      }
      final cacheRaw = await file.readAsString();
      if (cacheRaw.trim().isEmpty) {
        return const <AppData>[];
      }
      return _parseAppsJson(cacheRaw, enabledKeys);
    } catch (e, st) {
      appLogger.error('Failed to load cached apps', e, st);
      return const <AppData>[];
    }
  }

  List<AppData> _applyEnabledState(
    List<AppData> apps,
    Set<String> enabledKeys,
  ) {
    return apps.map((app) {
      final matchKey = _splitTunnelMatchKey(
        app.bundleId,
        app.appPath,
        app.name,
      );
      return app.copyWith(isEnabled: enabledKeys.contains(matchKey));
    }).toList();
  }

  List<AppData> _parseAppsJson(
    String jsonApps, [
    Set<String> enabledKeys = const <String>{},
  ]) {
    final dynamic decoded = jsonDecode(jsonApps);
    if (decoded is! List) {
      return const <AppData>[];
    }

    final deduped = <String, AppData>{};
    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }

      final raw = entry.cast<String, dynamic>();
      final name = (raw["name"] as String? ?? "").trim();
      final bundleId = (raw["bundleId"] as String? ?? "").trim();
      final appPath = (raw["appPath"] as String? ?? "").trim();
      final iconPath = (raw["iconPath"] as String? ?? '').trim();

      final matchKey = _splitTunnelMatchKey(bundleId, appPath, name);
      if (matchKey.isEmpty) {
        continue;
      }

      final app = AppData(
        name: name,
        bundleId: bundleId,
        appPath: appPath,
        iconPath: iconPath,
        iconBytes: iconToBytes(raw["icon"] ?? raw["iconBytes"]),
        isEnabled: enabledKeys.contains(matchKey),
      );

      final identity = _appIdentityKey(app);
      if (identity.isEmpty) {
        continue;
      }

      final existing = deduped[identity];
      if (existing == null ||
          ((existing.iconBytes?.isEmpty ?? true) &&
              (app.iconBytes?.isNotEmpty ?? false))) {
        deduped[identity] = app;
      }
    }

    final apps = deduped.values.toList();
    apps.sort((a, b) {
      final an = a.name.trim().toLowerCase();
      final bn = b.name.trim().toLowerCase();
      if (an.isEmpty && bn.isEmpty) return 0;
      if (an.isEmpty) return 1;
      if (bn.isEmpty) return -1;
      return an.compareTo(bn);
    });
    return apps;
  }

  String _splitTunnelMatchKey(String bundleId, String appPath, String name) {
    if (bundleId.isNotEmpty) return _normalizeSplitTunnelKey(bundleId);
    if (appPath.isNotEmpty) return _normalizeSplitTunnelKey(appPath);
    return _normalizeSplitTunnelKey(name);
  }

  String _normalizeSplitTunnelKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (Platform.isWindows) {
      return trimmed.toLowerCase();
    }
    return trimmed;
  }

  String _appIdentityKey(AppData app) {
    final bundleId = app.bundleId.trim().toLowerCase();
    if (bundleId.isNotEmpty) return bundleId;
    final appPath = app.appPath.trim().toLowerCase();
    if (appPath.isNotEmpty) return appPath;
    return app.name.trim().toLowerCase();
  }

  // Split tunneling
  static void _commandIsolateEntry(SendPort sendPort) {
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);

    commandPort.listen((message) async {
      final msg = message as SplitTunnelMessage;
      try {
        final result = await _runSplitTunnelCall(
          msg.type,
          msg.value,
          msg.action,
        );

        if (result.isLeft()) {
          final failure = result.fold((f) => f, (_) => null)!;
          msg.replyPort.send({
            'isError': true,
            'error': failure.error,
            'localizedErrorMessage': failure.localizedErrorMessage,
          });
        } else {
          msg.replyPort.send({'isError': false});
        }
      } catch (e) {
        msg.replyPort.send({
          'isError': true,
          'error': e.toString(),
          'localizedErrorMessage': e.toString(),
        });
      }
    });
  }

  Future<void> _initializeCommandIsolate() async {
    await Isolate.spawn(_commandIsolateEntry, commandReceivePort.sendPort);
    final port = await commandReceivePort.first;
    _commandSendPort = port as SendPort;
    _isolateInitialized.complete();
  }

  Future<Either<Failure, Unit>> _sendSplitTunnel(
    SplitTunnelFilterType type,
    String value,
    SplitTunnelActionType action,
  ) async {
    final responsePort = ReceivePort();

    if (_commandSendPort == null) {
      throw StateError('Command isolate not initialized');
    }

    _commandSendPort!.send(
      SplitTunnelMessage(type, value, action, responsePort.sendPort),
    );

    final result = await responsePort.first;
    responsePort.close();

    if (result is Map && result['isError'] == true) {
      return left(
        Failure(
          error: result['error'] ?? 'Unknown error',
          localizedErrorMessage:
              result['localizedErrorMessage'] ??
              result['error'] ??
              'Unknown error',
        ),
      );
    }

    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    return _sendSplitTunnel(type, value, SplitTunnelActionType.add);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    return _sendSplitTunnel(type, value, SplitTunnelActionType.remove);
  }

  @override
  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .setSplitTunnelingEnabled(enabled ? 1 : 0)
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error setting split tunneling', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isSplitTunnelingEnabled() async {
    try {
      final enabledInt = _ffiService.isSplitTunnelingEnabled();
      final enabled = enabledInt != 0;
      return right(enabled);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.getDataCapInfo().toDartString();
      });
      checkAPIError(result);
      final map = jsonDecode(result);
      appLogger.debug('Data cap info: $map');
      final dataCap = DataCapUsageResponse.fromJson(map);
      return right(dataCap);
    } catch (e, st) {
      appLogger.error('Failed to get data cap info: $e', e, st);
      return Left(e.toFailure());
    }
  }

  static Future<Either<Failure, Unit>> _runSplitTunnelCall(
    SplitTunnelFilterType type,
    String value,
    SplitTunnelActionType action,
  ) async {
    final tPtr = type.value.toNativeUtf8();
    final vPtr = value.toNativeUtf8();

    try {
      final fn = action == SplitTunnelActionType.add
          ? _ffiService.addSplitTunnelItem
          : _ffiService.removeSplitTunnelItem;

      final result = fn(tPtr.cast<Char>(), vPtr.cast<Char>());
      if (result != nullptr) {
        final error = result.cast<Utf8>().toDartString();
        malloc.free(result);
        appLogger.error('$action split tunnel error: $error');
        return left(Failure(error: error, localizedErrorMessage: error));
      }

      return right(unit);
    } catch (e) {
      return left(
        Failure(
          error: e.toString(),
          localizedErrorMessage: (e is Exception)
              ? e.localizedDescription
              : e.toString(),
        ),
      );
    } finally {
      malloc.free(tPtr);
      malloc.free(vPtr);
    }
  }

  @override
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  ) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .reportIssue(
              email.toCharPtr,
              issueType.toCharPtr,
              description.toCharPtr,
              device.toCharPtr,
              model.toCharPtr,
              "".toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('Error reporting issue: $e', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
    if (Platform.isWindows) {
      appLogger.debug('Starting VPN on Windows via IPC');

      try {
        final result = runInBackground(() async {
          return _ffiService.startAutoLocationListener().toDartString();
        });
        result.then((value) {
          appLogger.debug("auto location listener started: $value");
        });
      } catch (e) {
        appLogger.error("error starting auto location listener: $e");
      }

      final ws = await _getOrInitWindowsService(forceRetry: true);
      if (ws == null) {
        return left(
          Failure(
            error: 'Windows service unavailable',
            localizedErrorMessage: _windowsIpcUnavailableMessage(),
          ),
        );
      }

      ws.setNextStatusOrigin(VPNStatusOrigin.userAction);
      return ws.connect();
    }

    final ffiPaths = await PlatformFfiUtils.getFfiPlatformPaths();
    try {
      appLogger.debug('Starting VPN');
      final result = _ffiService
          .startVPN(
            ffiPaths.logFilePathPtr.cast<Char>(),
            ffiPaths.dataDirPtr.cast<Char>(),
            ffiPaths.localePtr.cast<Char>(),
          )
          .cast<Utf8>()
          .toDartString();
      if (result.isNotEmpty && !_ffiOkResults.contains(result)) {
        return left(Failure(error: result, localizedErrorMessage: result));
      }
      appLogger.debug('startVPN result: $result');
      return right(result.isEmpty ? 'ok' : result);
    } catch (e) {
      appLogger.error('Error starting VPN: $e');
      return Left(e.toFailure());
    } finally {
      ffiPaths.free();
    }
  }

  @override
  Future<bool> isTagAvailable(String tag) async {
    try {
      final result = await runInBackground<String>(() async {
        final tagPtr = tag.toCharPtr;
        try {
          final resultPtr = _ffiService.isTagAvailable(tagPtr);
          if (resultPtr == nullptr) {
            return 'true';
          }
          try {
            return resultPtr.toDartString();
          } finally {
            _ffiService.freeCString(resultPtr);
          }
        } finally {
          malloc.free(tagPtr);
        }
      });
      return result == 'true';
    } catch (e, st) {
      appLogger.error(
        'Error checking tag availability, assuming available',
        e,
        st,
      );
      return true;
    }
  }

  @override
  Future<bool> checkVpnConflict() async => false;

  /// connectToServer is used to connect to a server
  /// this will work with lantern customer and private server
  /// requires location and tag
  @override
  Future<Either<Failure, String>> connectToServer(
    String location,
    String tag,
  ) async {
    if (Platform.isWindows) {
      try {
        // Do not await here to avoid blocking
        final result = runInBackground(() async {
          return _ffiService.stopAutoLocationListener().toDartString();
        });
        result.then((value) {
          appLogger.debug("auto location listener stops : $value");
        });
      } catch (e) {
        appLogger.error("error stopping auto location listener: $e");
      }

      final ws = await _getOrInitWindowsService(forceRetry: true);
      if (ws == null) {
        return left(
          Failure(
            error: 'Windows service unavailable',
            localizedErrorMessage:
                'Cannot connect to a server: ${_windowsIpcUnavailableMessage()}',
          ),
        );
      }

      ws.setNextStatusOrigin(VPNStatusOrigin.userAction);
      return ws.connectToServer(location, tag);
    }

    final ffiPaths = await PlatformFfiUtils.getFfiPlatformPaths();
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .connectToServer(
              location.toCharPtr,
              tag.toCharPtr,
              ffiPaths.logFilePathPtr.cast<Char>(),
              ffiPaths.dataDirPtr.cast<Char>(),
              ffiPaths.localePtr.cast<Char>(),
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error connecting to server', e, stackTrace);
      return Left(e.toFailure());
    } finally {
      ffiPaths.free();
    }
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    try {
      appLogger.debug('Stopping VPN');

      if (Platform.isWindows) {
        // Best-effort: stop the listener without blocking the UI.
        try {
          final result = runInBackground(() async {
            return _ffiService.stopAutoLocationListener().toDartString();
          });
          result.then((value) {
            appLogger.debug("auto location listener stops : $value");
          });
        } catch (e) {
          appLogger.error("error stopping auto location listener: $e");
        }

        final ws = _windowsService;
        if (ws == null) {
          // If IPC never came up, treat this as already stopped.
          appLogger.warning(
            'stopVPN(): Windows service not initialized; treating as already stopped',
          );
          return right('ok');
        }

        ws.setNextStatusOrigin(VPNStatusOrigin.userAction);
        return ws.disconnect();
      }

      final result = _ffiService.stopVPN().cast<Utf8>().toDartString();
      if (result.isNotEmpty && !_ffiOkResults.contains(result)) {
        return left(Failure(error: result, localizedErrorMessage: result));
      }
      appLogger.debug('stopVPN result: $result');
      return right(result.isEmpty ? 'ok' : result);
    } catch (e) {
      appLogger.error('Error stopping VPN: $e');
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isVPNConnected() async {
    try {
      if (Platform.isWindows) {
        final ws = await _getOrInitWindowsService();
        if (ws == null) {
          return right(false);
        }
        return ws.isVPNConnected();
      }
      final connectedInt = _ffiService.isVPNConnected();
      final connected = connectedInt != 0;
      return right(connected);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, Unit>> _okOrFailureFromString(String result) async {
    try {
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('FFI call returned error', e, st);
      return left(e.toFailure());
    }
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    if (PlatformUtils.isWindows) {
      appLogger.info('[watchLogs] awaiting Windows service init');
      return Stream.fromFuture(_getOrInitWindowsService()).asyncExpand((ws) {
        if (ws == null) {
          appLogger.error(
            '[watchLogs] Windows service is null — returning empty stream',
          );
          return const Stream<List<String>>.empty();
        }
        appLogger.info(
          '[watchLogs] Windows service ready, starting log pipe stream',
        );
        return accumulateLogBatches(ws.watchLogs());
      });
    }
    throw UnimplementedError();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (Platform.isWindows) {
      return _watchWindowsStatus();
    }
    return _status;
  }

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    throw UnimplementedError("This not supported on desktop");
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect({
    required BillingType type,
    required String planId,
    required String email,
  }) async {
    try {
      appLogger.debug('Starting Stripe Subscription Payment Redirect');
      final result = await runInBackground<String>(() async {
        return _ffiService
            .stripeSubscriptionPaymentRedirect(
              type.name.toCharPtr,
              planId.toCharPtr,
              email.toCharPtr,
            )
            .toDartString();
      });

      return right(result);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription({
    required String planId,
    required String email,
  }) {
    throw Exception("Desktop flow should not be here, this is just for mobile");
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.stripeBillingPortalUrl().toDartString();
      });
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('Error getting stipe billing', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.plans().toDartString();
      });
      final map = jsonDecode(result);
      final plans = PlansData.fromJson(map);

      // Sort plans
      plans.plans.sort((a, b) {
        if (a.bestValue != b.bestValue) {
          return a.bestValue ? -1 : 1;
        }
        // Then: sort by usdPrice descending
        return b.usdPrice.compareTo(a.usdPrice);
      });

      plans.providers.desktop.sort((a, b) {
        return (b.providers.supportSubscription ? 1 : 0) -
            (a.providers.supportSubscription ? 1 : 0);
      });

      appLogger.info('Plans: $map');
      return Right(plans);
    } catch (e, stackTrace) {
      appLogger.error('error getting plans', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.oauthLoginUrl(provider.toCharPtr).toDartString();
      });
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('error getting oauth url', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.oAuthLoginCallback(token.toCharPtr).toDartString();
      });
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('error oauth callback', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> getUserData() async {
    // if (Platform.isWindows) {
    //   return _windowsService.getUserData();
    // }
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.getUserData().toDartString();
      });
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('Error getting user data', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() {
    throw Exception("This not supported on desktop, this is only for mobile");
  }

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.fetchUserData().toDartString();
      });
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('error fetchUser data', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  }) {
    throw Exception("This not supported on desktop, this is only for mobile");
  }

  @override
  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .paymentRedirect(
              planId.toCharPtr,
              provider.toCharPtr,
              email.toCharPtr,
            )
            .toDartString();
      });
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('error payment redirect', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> logout(String email) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.logout(email.toCharPtr).toDartString();
      });
      checkAPIError(result);
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('error while logout', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .login(email.toCharPtr, password.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('error while login', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.startRecoveryByEmail(email.toCharPtr).toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting recovery by email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode({
    required String email,
    required String code,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .validateEmailRecoveryCode(email.toCharPtr, code.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .completeRecoveryByEmail(
              email.toCharPtr,
              newPassword.toCharPtr,
              code.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .signup(email.toCharPtr, password.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .deleteAccount(email.toCharPtr, password.toCharPtr, isSSO ? 1 : 0)
            .toDartString();
      });
      checkAPIError(result);
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('Error deleting account', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> activationCode({
    required String email,
    required String resellerCode,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .activationCode(email.toCharPtr, resellerCode.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.digitalOceanPrivateServer().toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
        'Error starting Digital Ocean private server',
        e,
        stackTrace,
      );
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.googleCloudPrivateServer().toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
        'Error starting Digital Ocean private server',
        e,
        stackTrace,
      );
      return Left(e.toFailure());
    }
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    return _privateServerStatus;
  }

  @override
  Future<Either<Failure, Unit>> validateSession() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.validateSession().toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info('Error validating session', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setUserInput({
    required PrivateServerInput methodType,
    required String input,
  }) async {
    try {
      final value = input.toCharPtr;
      final result = await runInBackground<String>(() async {
        switch (methodType) {
          case PrivateServerInput.selectAccount:
            return _ffiService.selectAccount(value).toDartString();
          case PrivateServerInput.selectProject:
            return _ffiService.selectProject(value).toDartString();
        }
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
        'Error starting Digital Ocean private server',
        e,
        stackTrace,
      );
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startDeployment({
    required String location,
    required String serverName,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .startDepolyment(location.toCharPtr, serverName.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelDeployment() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.cancelDepolyment().toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addServerManually({
    required String ip,
    required String port,
    required String accessToken,
    required String serverName,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .addServerManagerInstance(
              ip.toCharPtr,
              port.toCharPtr,
              accessToken.toCharPtr,
              serverName.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error adding server manually', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addServerBasedOnURLs({
    required String urls,
    required bool skipCertVerification,
    required String serverName,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .addServerBasedOnURLs(
              urls.toCharPtr,
              skipCertVerification ? 1 : 0,
              serverName.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error adding server based on URLs', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .inviteToServerManagerInstance(
              ip.toCharPtr,
              port.toCharPtr,
              accessToken.toCharPtr,
              inviteName.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error(
        'Error inviting to server manager instance',
        e,
        stackTrace,
      );
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .revokeServerManagerInvite(
              ip.toCharPtr,
              port.toCharPtr,
              accessToken.toCharPtr,
              inviteName.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error revoking server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePrivateServerByName(String name) async {
    try {
      final namePtr = name.toNativeUtf8();

      try {
        final result = await runInBackground<String>(() async {
          return _ffiService
              .deletePrivateServerByName(namePtr.cast<Char>())
              .toDartString();
        });

        return _okOrFailureFromString(result);
      } finally {
        malloc.free(namePtr);
      }
    } catch (e, st) {
      appLogger.error('deletePrivateServerByName failed', e, st);
      return left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updatePrivateServerName(
    String oldName,
    String newName,
  ) async {
    try {
      final oldPtr = oldName.toNativeUtf8();
      final newPtr = newName.toNativeUtf8();

      try {
        final result = await runInBackground<String>(() async {
          return _ffiService
              .updatePrivateServerName(oldPtr.cast<Char>(), newPtr.cast<Char>())
              .toDartString();
        });

        return _okOrFailureFromString(result);
      } finally {
        malloc.free(oldPtr);
        malloc.free(newPtr);
      }
    } catch (e, st) {
      appLogger.error('updatePrivateServerName failed', e, st);
      return left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> featureFlag() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.availableFeatures().toDartString();
      });
      checkAPIError(result);
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('Error getting feature flag', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.getAvailableServers().toDartString();
      });
      checkAPIError(result);
      final servers = AvailableServers.fromJson(jsonDecode(result));
      void applyProtocols(Lantern lantern) {
        final outboundsByTag = {
          for (var outbound in lantern.outbounds) outbound.tag: outbound.type,
        };
        lantern.locations.forEach((key, value) {
          final protoValue = outboundsByTag[key];
          if (protoValue != null) {
            value.protocol = protoValue;
          } else {
            try {
              // If not found, try to extract from tag.
              value.protocol = value.tag.split('-').first;
            } catch (_) {
              // If anything goes wrong, just leave it blank.
              value.protocol = '';
            }
          }
        });
      }

      applyProtocols(servers.lantern);
      applyProtocols(servers.user);
      return Right(servers);
    } catch (e, stackTrace) {
      appLogger.error('Error getting available servers', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> deviceRemove({
    required String deviceId,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.removeDevice(deviceId.toCharPtr).toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error removing device', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> attachReferralCode(String code) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.referralAttachment(code.toCharPtr).toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error attaching referral code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> completeChangeEmail({
    required String newEmail,
    required String password,
    required String code,
  }) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .completeChangeEmail(
              newEmail.toCharPtr,
              password.toCharPtr,
              code.toCharPtr,
            )
            .toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
    String newEmail,
    String password,
  ) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .startChangeEmail(newEmail.toCharPtr, password.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error starting change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Server>> getAutoServerLocation() async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.getAutoLocation().toDartString();
      });
      checkAPIError(result);
      return Right(Server.fromJson(jsonDecode(result)));
    } catch (e, stackTrace) {
      appLogger.error('Error while getting auto location', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled) async {
    try {
      await _markWindowsStatusOrigin(VPNStatusOrigin.settingsMutation);
      final result = await runInBackground<String>(() async {
        return _ffiService
            .setBlockAdsEnabled(enabled ? 1 : 0)
            .cast<Utf8>()
            .toDartString();
      });
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('setBlockAdsEnabled error: $e', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() async {
    try {
      final res = _ffiService.isBlockAdsEnabled();
      return right(res != 0);
    } catch (e, st) {
      appLogger.error('isBlockAdsEnabled error: $e', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> triggerSystemExtension() {
    throw Exception("This is not supported on desktop");
  }

  @override
  Future<Either<Failure, Unit>> openSystemExtension() {
    // TODO: implement openSystemExtension
    throw UnimplementedError();
  }

  @override
  Stream<MacOSExtensionState> watchSystemExtensionStatus() {
    // TODO: implement watchSystemExtensionStatus
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> isSystemExtensionInstalled() {
    // TODO: implement isSystemExtensionInstalled
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> addAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  ) async {
    final items = value
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false);

    for (final item in items) {
      final result = await addSplitTunnelItem(type, item);
      if (result.isLeft()) {
        return result;
      }
    }

    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  ) async {
    final items = value
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList(growable: false);

    for (final item in items) {
      final result = await removeSplitTunnelItem(type, item);
      if (result.isLeft()) {
        return result;
      }
    }

    return right(unit);
  }

  @override
  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  ) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService
            .getSplitTunnelItems(type.value.toCharPtr)
            .toDartString();
      });
      checkAPIError(result);

      if (result.trim().isEmpty) {
        return right(<String>[]);
      }

      final decoded = jsonDecode(result);
      if (decoded is! List) {
        return right(<String>[]);
      }

      final items = decoded
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);

      return right(items);
    } catch (e, st) {
      appLogger.error('getSplitTunnelItems failed', e, st);
      return left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateLocal(String locale) async {
    try {
      final result = await runInBackground<String>(() async {
        return _ffiService.updateLocale(locale.toCharPtr).toDartString();
      });
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error while updating local', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, List<String>>> diagnosticLogFiles() {
    // TODO: implement diagnosticLogFiles
    throw UnimplementedError();
  }
}

enum _WindowsServiceState {
  running,
  stopped,
  startPending,
  stopPending,
  missing,
  unknown,
}

void checkAPIError(dynamic result) {
  if (result is String) {
    if (result == 'true' || result == 'ok') {
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(result);
    } catch (_) {
      return;
    }
    if (decoded is Map && decoded.containsKey('error')) {
      appLogger.error('API Error: ${decoded['error']}');
      throw PlatformException(
        code: decoded['error'].toString(),
        message: decoded['error'].toString(),
      );
    }
    return;
  }
  if (result.error != "") {
    throw PlatformException(code: result.error, message: result.error);
  }
}

class SplitTunnelMessage {
  final SplitTunnelFilterType type;
  final String value;
  final SplitTunnelActionType action;
  final SendPort replyPort;

  SplitTunnelMessage(this.type, this.value, this.action, this.replyPort);
}

class PlatformFfiUtils {
  static Future<FfiPlatformPaths> getFfiPlatformPaths() async {
    final logFile = await AppStorageUtils.appLogFile();
    final dataDir = await AppStorageUtils.getAppDirectory();
    final locale = PlatformDispatcher.instance.locale.toString();

    final logFilePathPtr = logFile.path.toNativeUtf8();
    final dataDirPtr = dataDir.path.toNativeUtf8();
    final localePtr = locale.toNativeUtf8();

    return FfiPlatformPaths(
      logFilePathPtr: logFilePathPtr,
      dataDirPtr: dataDirPtr,
      localePtr: localePtr,
    );
  }
}

class FfiPlatformPaths {
  final Pointer<Utf8> logFilePathPtr;
  final Pointer<Utf8> dataDirPtr;
  final Pointer<Utf8> localePtr;

  FfiPlatformPaths({
    required this.logFilePathPtr,
    required this.dataDirPtr,
    required this.localePtr,
  });

  void free() {
    malloc.free(logFilePathPtr);
    malloc.free(dataDirPtr);
    malloc.free(localePtr);
  }
}

class MockLanternFFIService extends LanternFFIService {
  @override
  Future<void> init() async {}
}
