import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/mapper/plan_mapper.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';
import 'package:path/path.dart' as p;

import '../core/models/plan_data.dart';
import '../core/services/injection_container.dart' show sl;
import '../core/utils/compute_worker.dart';

export 'dart:convert';
export 'dart:ffi'; // For FFI

export 'package:ffi/src/utf8.dart';

const String _libName = 'liblantern';

///this service should communicate with library using ffi
///also this should be called from only [LanternService]
class LanternFFIService implements LanternCoreService {
  static final LanternBindings _ffiService = _gen();

  late final Stream<LanternStatus> _status;

  static SendPort? _commandSendPort;
  static final Completer<void> _isolateInitialized = Completer<void>();

  // Receive ports for different app services
  static final commandReceivePort = ReceivePort();
  static final statusReceivePort = ReceivePort();
  static final appsReceivePort = ReceivePort();
  static final loggingReceivePort = ReceivePort();

  static LanternBindings _gen() {
    String fullPath = "";
    if (Platform.isWindows) {
      fullPath = p.join(fullPath, "bin/windows", "$_libName.dll");
    } else if (Platform.isMacOS) {
      fullPath = p.join(fullPath, "$_libName.dylib");
    } else {
      fullPath = p.join(fullPath, "$_libName.so");
    }
    appLogger.debug('singbox native libs path: "$fullPath"');
    final lib = DynamicLibrary.open(fullPath);
    return LanternBindings(lib);
  }

  Future<Either<String, Unit>> _setupRadiance(nativePort) async {
    try {
      appLogger.debug('Setting up radiance');
      final dataDir = await AppStorageUtils.getAppDirectory();
      final logDir = await AppStorageUtils.getAppLogDirectory();
      appLogger.debug('Data dir: ${dataDir.path}');
      appLogger.debug('Log dir: $logDir');
      final dataDirPtr = dataDir.path.toNativeUtf8();
      final logDirPtr = logDir.toNativeUtf8();

      _ffiService.setup(
        logDirPtr.cast(),
        dataDirPtr.cast(),
        Localization.defaultLocale.toCharPtr,
        loggingReceivePort.sendPort.nativePort,
        appsReceivePort.sendPort.nativePort,
        statusReceivePort.sendPort.nativePort,
        NativeApi.initializeApiDLData,
      );

      malloc.free(dataDirPtr);
      malloc.free(logDirPtr);
      return right(unit);
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
      return left('Error while setting up radiance');
    }
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    final apps = <AppData>[];

    await for (final message in appsReceivePort) {
      try {
        if (message is String) {
          final List<dynamic> decoded = jsonDecode(message);
          apps.addAll(decoded
              .map((json) => AppData.fromJson(json as Map<String, dynamic>))
              .toList());

          yield [...apps];
        }
      } catch (e) {
        appLogger.error("Failed to decode AppData: $e");
      }
    }
  }

  @override
  Stream<List<String>> logsStream() async* {
    await for (final message in loggingReceivePort) {
      yield message;
    }
  }

  // Split tunneling
  static void _commandIsolateEntry(SendPort sendPort) {
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);
    commandPort.listen((message) async {
      final msg = message as SplitTunnelMessage;
      try {
        final result =
            await _runSplitTunnelCall(msg.type, msg.value, msg.action);
        msg.replyPort.send(result);
      } catch (e) {
        msg.replyPort.send(left(Failure(
          error: e.toString(),
          localizedErrorMessage: e.toString(),
        )));
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
    _commandSendPort!
        .send(SplitTunnelMessage(type, value, action, responsePort.sendPort));

    final result = await responsePort.first;
    responsePort.close();
    return result;
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    return _sendSplitTunnel(
      type,
      value,
      SplitTunnelActionType.add,
    );
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    return _sendSplitTunnel(
      type,
      value,
      SplitTunnelActionType.remove,
    );
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
        return left(
          Failure(
            error: error,
            localizedErrorMessage: error,
          ),
        );
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
  Future<Either<Failure, String>> startVPN() async {
    try {
      appLogger.debug('Starting VPN');

      final result = _ffiService.startVPN().cast<Utf8>().toDartString();
      if (result.isNotEmpty) {
        return left(Failure(
          error: result,
          localizedErrorMessage: result,
        ));
      }
      appLogger.debug('startVPN result: $result');
      return right(result);
    } catch (e) {
      appLogger.error('Error starting VPN: $e');
      return Left(e.toFailure());
    }
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    throw UnimplementedError();
  }

  Future<Either<Failure, String>> stopVPN() async {
    try {
      appLogger.debug('Stopping VPN');
      final result = _ffiService.stopVPN().cast<Utf8>().toDartString();
      if (result.isNotEmpty) {
        return left(Failure(error: result, localizedErrorMessage: ''));
      }
      appLogger.debug('stopVPN result: $result');
      return right(result);
    } catch (e) {
      appLogger.error('Error stopping VPN: $e');
      return Left(e.toFailure());
    }
  }

  @override
  Future<void> init() async {
    try {
      await _initializeCommandIsolate();
      final nativePort = statusReceivePort.sendPort.nativePort;
      // setup receive port to receive connection status updates
      _status = statusReceivePort.map(
        (event) {
          Map<String, dynamic> result = jsonDecode(event);
          return LanternStatus.fromJson(result);
        },
      );

      await _setupRadiance(nativePort);
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
    }
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => _status;

  @override
  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      final result = _ffiService.isVPNConnected();
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow(
      {required String planId,
      required PaymentSuccessCallback onSuccess,
      required PaymentErrorCallback onError}) {
    throw UnimplementedError("This not supported on desktop");
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required BillingType type,
      required String planId,
      required String email}) async {
    try {
      appLogger.debug('Starting Stripe Subscription Payment Redirect');
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .stripeSubscriptionPaymentRedirect(
                type.name.toCharPtr,
                planId.toCharPtr,
                email.toCharPtr,
              )
              .toDartString();
        },
      );

      return right(result);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId, required String email}) {
    // TODO: implement stipeSubscription
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.stripeBillingPortalUrl().toDartString();
        },
      );
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('Error getting stipe billing', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.plans().toDartString();
        },
      );
      final map = jsonDecode(result);
      final plans = PlansData.fromJson(map);
      sl<LocalStorageService>().savePlans(plans.toEntity());
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService.oauthLoginUrl(provider.toCharPtr).toDartString();
        },
      );
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('error getting oauth url', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.oAuthLoginCallback(token.toCharPtr).toDartString();
        },
      );
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
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.getUserData().toDartString();
        },
      );
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
    // TODO: implement showManageSubscriptions
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.fetchUserData().toDartString();
        },
      );
      final decodedResult = base64Decode(result);
      final user = UserResponse.fromBuffer(decodedResult);
      return Right(user);
    } catch (e, stackTrace) {
      appLogger.error('error fetchUser data', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeInAppPurchase(
      {required String purchaseToken, required String planId}) {
    // TODO: implement acknowledgeInAppPurchase
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, String>> paymentRedirect(
      {required String provider,
      required String planId,
      required String email}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .paymentRedirect(
                planId.toCharPtr,
                provider.toCharPtr,
                email.toCharPtr,
              )
              .toDartString();
        },
      );
      return Right(result);
    } catch (e, stackTrace) {
      appLogger.error('error payment redirect', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> logout(String email) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.logout(email.toCharPtr).toDartString();
        },
      );
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
  Future<Either<Failure, UserResponse>> login(
      {required String email, required String password}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .login(email.toCharPtr, password.toCharPtr)
              .toDartString();
        },
      );
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .startRecoveryByEmail(email.toCharPtr)
              .toDartString();
        },
      );
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .validateEmailRecoveryCode(email.toCharPtr, code.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> completeChangeEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .completeRecoveryByEmail(
                  email.toCharPtr, newPassword.toCharPtr, code.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signUp(
      {required String email, required String password}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .signup(email.toCharPtr, password.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> deleteAccount({required String email, required String password}) async {
  try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .deleteAccount(email.toCharPtr, password.toCharPtr)
              .toDartString();
        },
      );
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
  Future<Either<Failure, Unit>> activationCode({required String email, required String resellerCode}) async {
  try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .activationCode(email.toCharPtr, resellerCode.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() {
    // TODO: implement digitalOceanPrivateServer
    throw UnimplementedError();
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    // TODO: implement watchPrivateServerStatus
    throw UnimplementedError();
  }
}

void checkAPIError(result) {
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

class MockLanternFFIService extends LanternFFIService {}
