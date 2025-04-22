import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:path/path.dart' as p;
import 'package:rxdart/rxdart.dart';

import '../core/models/plan_data.dart';
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
      fullPath = p.join(fullPath, "$_libName.dll");
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
      final dataDirPtr = dataDir.path.toNativeUtf8();
      final logDirPtr = logDir.toNativeUtf8();

      _ffiService.setup(
        dataDirPtr.cast(),
        logDirPtr.cast(),
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
      return left(
        Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription,
        ),
      );
    }
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
      return left(
        Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription,
        ),
      );
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
      ).debounceTime(const Duration(milliseconds: 200));

      await _setupRadiance(nativePort);
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
    }
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => _status.asBroadcastStream();

  @override
  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      final result = _ffiService.isVPNConnected();
      return right(unit);
    } catch (e) {
      return left(
        Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelSubscription() {
    // TODO: implement cancelSubscription
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID}) {
    // TODO: implement makeOneTimePayment
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> startSubscriptionFlow(
      {required String planId,
      required PaymentSuccessCallback onSuccess,
      required PaymentErrorCallback onError}) {
    // TODO: implement subscribeToPlan
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required StipeSubscriptionType type, required String planId}) async {
    try {
      appLogger.debug('Starting Stripe Subscription Payment Redirect');
      final result = await runInBackground<String>(
        () async {
          return _ffiService
              .stripeSubscriptionPaymentRedirect(type.name.toCharPtr)
              .toDartString();
        },
      );

      return right(result);
    } catch (e) {
      return left(
        Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId}) {
    // TODO: implement stipeSubscription
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, PlansData>> plans() {
    // TODO: implement plans
    throw UnimplementedError();
  }
}

class SplitTunnelMessage {
  final SplitTunnelFilterType type;
  final String value;
  final SplitTunnelActionType action;
  final SendPort replyPort;

  SplitTunnelMessage(this.type, this.value, this.action, this.replyPort);
}


class MockLanternFFIService extends LanternFFIService{

}