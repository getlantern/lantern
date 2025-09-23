import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/datacap_info.dart';
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

import '../core/models/available_servers.dart';
import '../core/models/macos_extension_state.dart';
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
  late Stream<PrivateServerStatus> _privateServerStatus;

  static SendPort? _commandSendPort;
  static final Completer<void> _isolateInitialized = Completer<void>();

  // Receive ports for different app services
  static final commandReceivePort = ReceivePort();
  static final statusReceivePort = ReceivePort();
  static final privateServerReceivePort = ReceivePort();
  static final appsReceivePort = ReceivePort();
  static final loggingReceivePort = ReceivePort();

  static LanternBindings _gen() {
    String fullPath = "";
    if (Platform.isWindows) {
      fullPath = p.join(fullPath, "bin/windows", "$_libName.dll");
    } else {
      fullPath = p.join(fullPath, "$_libName.so");
    }
    appLogger.debug('singbox native libs path: "$fullPath"');
    final lib = DynamicLibrary.open(fullPath);
    return LanternBindings(lib);
  }

  Future<Either<String, Unit>> _setupRadiance() async {
    try {
      appLogger.debug('Setting up radiance');
      final dataDir = await AppStorageUtils.getAppDirectory();
      final logDir = await AppStorageUtils.getAppLogDirectory();
      appLogger.debug("Data dir: ${dataDir.path}, Log dir: $logDir");
      final dataDirPtr = dataDir.path.toCharPtr;
      final logDirPtr = logDir.toCharPtr;
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .setup(
                logDirPtr,
                dataDirPtr,
                Localization.defaultLocale.toCharPtr,
                loggingReceivePort.sendPort.nativePort,
                appsReceivePort.sendPort.nativePort,
                statusReceivePort.sendPort.nativePort,
                privateServerReceivePort.sendPort.nativePort,
                NativeApi.initializeApiDLData,
              )
              .toDartString();
        },
      );
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('Failed to get data cap info: $e', e, st);
      return Left(e.toFailure().localizedErrorMessage);
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

      _privateServerStatus = privateServerReceivePort.map((event) {
        Map<String, dynamic> result = jsonDecode(event);
        return PrivateServerStatus.fromJson(result);
      });

      await _setupRadiance();
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
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

  // Split tunneling
  static void _commandIsolateEntry(SendPort sendPort) {
    final commandPort = ReceivePort();
    sendPort.send(commandPort.sendPort);
    commandPort.listen((message) async {
      final msg = message as SplitTunnelMessage;
      try {
        final result =
            await _runSplitTunnelCall(msg.type, msg.value, msg.action);
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
    _commandSendPort!
        .send(SplitTunnelMessage(type, value, action, responsePort.sendPort));

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

  @override
  Future<Either<Failure, DataCapInfo>> getDataCapInfo() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.getDataCapInfo().toDartString();
        },
      );
      checkAPIError(result);
      final map = jsonDecode(jsonEncode(result));
      final dataCap = DataCapInfo.fromJson(map);
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
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  ) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .reportIssue(
                  email.toCharPtr,
                  issueType.toCharPtr,
                  description.toCharPtr,
                  device.toCharPtr,
                  model.toCharPtr,
                  "".toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return right(unit);
    } catch (e, st) {
      appLogger.error('Error reporting issue: $e', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
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
    } finally {
      ffiPaths.free();
    }
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    throw UnimplementedError();
  }

  @override
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
    throw Exception("Desktop flow should not be here, this is just for mobile");
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
    throw Exception("This not supported on desktop, this is only for mobile");
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
    throw Exception("This not supported on desktop, this is only for mobile");
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
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
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
  Future<Either<Failure, UserResponse>> deleteAccount(
      {required String email, required String password}) async {
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
  Future<Either<Failure, Unit>> activationCode(
      {required String email, required String resellerCode}) async {
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
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.digitalOceanPrivateServer().toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
          'Error starting Digital Ocean private server', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.googleCloudPrivateServer().toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
          'Error starting Digital Ocean private server', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    return _privateServerStatus;
  }

  @override
  Future<Either<Failure, Unit>> setUserInput(
      {required PrivateServerInput methodType, required String input}) async {
    try {
      final value = input.toCharPtr;
      final result = await runInBackground<String>(
        () async {
          switch (methodType) {
            case PrivateServerInput.selectAccount:
              return _ffiService.selectAccount(value).toDartString();
            case PrivateServerInput.selectProject:
              return _ffiService.selectProject(value).toDartString();
          }
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.info(
          'Error starting Digital Ocean private server', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startDeployment(
      {required String location, required String serverName}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .startDepolyment(location.toCharPtr, serverName.toCharPtr)
              .toDartString();
        },
      );
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService.cancelDepolyment().toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setCert({required String fingerprint}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.setCert(fingerprint.toCharPtr).toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addServerManually(
      {required String ip,
      required String port,
      required String accessToken,
      required String serverName}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .addServerManagerInstance(ip.toCharPtr, port.toCharPtr,
                  accessToken.toCharPtr, serverName.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error adding server manually', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  /// connectToServer is used to connect to a server
  /// this will work with lantern customer and private server
  /// requires location and tag
  @override
  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    final ffiPaths = await PlatformFfiUtils.getFfiPlatformPaths();
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .connectToServer(
                location.toCharPtr,
                tag.toCharPtr,
                ffiPaths.logFilePathPtr.cast<Char>(),
                ffiPaths.dataDirPtr.cast<Char>(),
                ffiPaths.localePtr.cast<Char>(),
              )
              .toDartString();
        },
      );
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
  Future<Either<Failure, String>> inviteToServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .inviteToServerManagerInstance(ip.toCharPtr, port.toCharPtr,
                  accessToken.toCharPtr, inviteName.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error(
          'Error inviting to server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .revokeServerManagerInvite(ip.toCharPtr, port.toCharPtr,
                  accessToken.toCharPtr, inviteName.toCharPtr)
              .toDartString();
        },
      );
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService.availableFeatures().toDartString();
        },
      );
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
      final result = await runInBackground<String>(
        () async {
          return _ffiService.getAvailableServers().toDartString();
        },
      );
      checkAPIError(result);
      return Right(AvailableServers.fromJson(jsonDecode(result)));
    } catch (e, stackTrace) {
      appLogger.error('Error getting available servers', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> deviceRemove(
      {required String deviceId}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService.removeDevice(deviceId.toCharPtr).toDartString();
        },
      );
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error removing device', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> completeChangeEmail(
      {required String newEmail,
      required String password,
      required String code}) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .completeChangeEmail(
                  newEmail.toCharPtr, password.toCharPtr, code.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
      String newEmail, String password) async {
    try {
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .startChangeEmail(newEmail.toCharPtr, password.toCharPtr)
              .toDartString();
        },
      );
      checkAPIError(result);
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error starting change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getAutoServerLocation() {
    // TODO: implement getAutoServerLocation
    throw UnimplementedError();
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
