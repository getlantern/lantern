import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/utils/app_data_utils.dart';
import 'package:lantern/core/utils/enabled_apps.dart';
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
import '../core/services/injection_container.dart' show sl;
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

  /// Windows IPC is optional. If it fails to init (missing token, timeout, etc),
  /// we keep going and fall back to the non-IPC paths.
  LanternServiceWindows? _windowsService;
  Future<LanternServiceWindows?>? _windowsServiceInitInFlight;

  Stream<LanternStatus> _status = _defaultStatusStream();

  Stream<PrivateServerStatus> _privateServerStatus =
      const Stream<PrivateServerStatus>.empty();
  Stream<AppEvent> _appEvents = const Stream<AppEvent>.empty();

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
        /// Start windows IPC service.
        /// Keep it alive, but we only use it for VPN-related calls.
        final ws = await _getOrInitWindowsService();
        if (ws != null) {
          _status = ws.watchVPNStatus();
        } else {
          appLogger.warning(
            'Windows IPC init failed; continuing without Windows service',
          );
        }

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
        final appSetting = sl<LocalStorageService>().getAppSetting();
        if (appSetting != null) {
          consent = appSetting.telemetryConsent ? 1 : 0;
        }
      } catch (_) {
        appLogger.warning(
          'No app setting found, defaulting telemetry consent to false',
        );
      }

      final dataDir = await AppStorageUtils.getAppDirectory();
      final logDir = await AppStorageUtils.getAppLogDirectory();
      appLogger.info(
          "Radiance configuration - env: $env, dataDir: ${dataDir.path}, logDir: $logDir, telemetryConsent: $consent");

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
        throw PlatformException(
          code: 'radiance_setup_failed',
          message: result,
        );
      }
      return right(unit);
    } catch (e, st) {
      appLogger.error('Failed to set up radiance: $e', e, st);
      return Left(e.toFailure().localizedErrorMessage);
    }
  }

  Future<void> _initializeWindowsService() async {
    final tokenPath = p.join(
      Platform.environment['ProgramData'] ?? r'C:\ProgramData',
      'Lantern',
      'ipc-token',
    );
    final pipe = PipeClient(tokenPath: tokenPath);

    // Create locally first; only assign to the field after init succeeds.
    final ws = LanternServiceWindows(pipe);

    try {
      await ws.init();
      _windowsService = ws;
    } catch (e, st) {
      appLogger.error('LanternServiceWindows.init() threw', e, st);
      _windowsService = null;
      rethrow; // init() will catch and keep going; this keeps the original stack.
    }
  }

  Future<LanternServiceWindows?> _getOrInitWindowsService() async {
    final existing = _windowsService;
    if (existing != null) {
      return existing;
    }

    final inFlight = _windowsServiceInitInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final initFuture = () async {
      try {
        await _initializeWindowsService();
      } catch (e, st) {
        appLogger.error('Windows IPC re-init failed', e, st);
        _windowsService = null;
      } finally {
        _windowsServiceInitInFlight = null;
      }
      return _windowsService;
    }();

    _windowsServiceInitInFlight = initFuture;
    return initFuture;
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
    try {
      final String dataDir = (await AppStorageUtils.getAppDirectory()).path;
      final String json = await runInBackground<String>(() async {
        final ptr = dataDir.toNativeUtf8();
        try {
          return _ffiService.loadInstalledApps(ptr.cast<Char>()).toDartString();
        } finally {
          malloc.free(ptr);
        }
      });

      if (json.isEmpty) {
        appLogger.debug("No installed apps found");
        yield [];
        return;
      }

      appLogger.debug("Loaded installed apps");
      final decoded = jsonDecode(json) as List<dynamic>;
      final enabled = EnabledApps(sl<LocalStorageService>()).snapshot();
      final rawApps = decoded.cast<Map<String, dynamic>>();
      yield _mapToAppData(rawApps, enabled);
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      yield [];
    }
  }

  List<AppData> _mapToAppData(
    Iterable<Map<String, dynamic>> rawApps,
    EnabledAppsSnapshot enabled,
  ) {
    return rawApps.map((raw) {
      final name = (raw["name"] as String? ?? "").trim();
      final bundleId = (raw["bundleId"] as String? ?? "").trim();

      final key = bundleId.isNotEmpty ? bundleId : name;
      final isEnabled = enabled.contains(key: key, name: name);

      return AppData(
        name: name,
        bundleId: bundleId,
        appPath: raw["appPath"] as String? ?? '',
        iconPath: raw["iconPath"] as String? ?? '',
        iconBytes: iconToBytes(raw["icon"] ?? raw["iconBytes"]),
        isEnabled: isEnabled,
      );
    }).toList();
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
          localizedErrorMessage: result['localizedErrorMessage'] ??
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
          localizedErrorMessage:
              (e is Exception) ? e.localizedDescription : e.toString(),
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

      final ws = await _getOrInitWindowsService();
      if (ws == null) {
        return left(
          Failure(
            error: 'Windows service unavailable',
            localizedErrorMessage:
                'The Windows VPN service did not initialize (IPC unavailable).',
          ),
        );
      }

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

      final ws = await _getOrInitWindowsService();
      if (ws == null) {
        return left(
          Failure(
            error: 'Windows service unavailable',
            localizedErrorMessage:
                'Cannot connect to a server because Windows IPC is unavailable.',
          ),
        );
      }

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

  @override
  Stream<List<String>> watchLogs(String path) {
    if (PlatformUtils.isWindows) {
      final ws = _windowsService;
      if (ws == null) {
        return const Stream<List<String>>.empty();
      }
      return ws.watchLogs();
    }
    throw UnimplementedError();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => _status;

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
  Future<Either<Failure, Unit>> addServerBasedOnURLs(
      {required String urls,
      required bool skipCertVerification,
      required String serverName}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .addServerBasedOnURLs(urls.toCharPtr,
                  skipCertVerification ? 1 : 0, serverName.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error adding server based on URLs', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
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
      final outboundsByTag = {
        for (var outbound in servers.lantern.outbounds)
          outbound.tag: outbound.type,
      };

      servers.lantern.locations.forEach((key, value) {
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
      final result = _ffiService
          .setBlockAdsEnabled(enabled ? 1 : 0)
          .cast<Utf8>()
          .toDartString();
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
  ) {
    // TODO: implement addAllItems
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> removeAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  ) {
    // TODO: implement removeAllItems
    throw UnimplementedError();
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

class MockLanternFFIService extends LanternFFIService {}
