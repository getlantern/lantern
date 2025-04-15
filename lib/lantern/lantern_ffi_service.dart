import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/extensions/error.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:path/path.dart' as p;

export 'dart:convert';
export 'dart:ffi'; // For FFI

export 'package:ffi/src/utf8.dart';

const String _libName = 'liblantern';

///this service should communicate with library using ffi
///also this should be called from only [LanternService]
class LanternFFIService implements LanternCoreService {
  static final LanternBindings _ffiService = _gen();
  late final Stream<LanternStatus> _status;
  static final statusReceivePort = ReceivePort();

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
        nativePort,
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
      final nativePort = statusReceivePort.sendPort.nativePort;
      // setup receive port to receive connection status updates
      _status = statusReceivePort.map(
        (event) {
          Map<String, dynamic> result = jsonDecode(jsonDecode(event));
          return LanternStatus.fromJson(result);
        },
      );

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
}
