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
import 'package:lantern/core/utils/log_utils.dart';
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

  @override
  Future<Either<String, Unit>> setupRadiance() async {
    try {
      appLogger.debug('Setting up radiance');
      final baseDir = await LogUtils.getAppLogDirectory();
      final baseDirPtr = baseDir.toNativeUtf8();

      // final result = await Isolate.run(
      //   () {
      //     return _ffiService
      //         .setupRadiance(
      //           baseDirPtr.cast(),
      //           loggingReceivePort.sendPort.nativePort,
      //           appsReceivePort.sendPort.nativePort,
      //           NativeApi.initializeApiDLData,
      //         )
      //         .cast<Utf8>()
      //         .toDartString();
      //   },
      // );

      final result = _ffiService
          .setupRadiance(
            baseDirPtr.cast(),
            loggingReceivePort.sendPort.nativePort,
            appsReceivePort.sendPort.nativePort,
            NativeApi.initializeApiDLData,
          )
          .cast<Utf8>()
          .toDartString();

      malloc.free(baseDirPtr);
      appLogger.debug('Radiance setup result: $result');
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

      final result = await Future(
          () => _ffiService.startVPN().cast<Utf8>().toDartString());
      if (result.isNotEmpty) {
        return left(Failure(error: result, localizedErrorMessage: ''));
      }
      appLogger.debug('startVPN result: $result');
      return right(result);
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
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
      appLogger.debug('Starting VPN');

      final result =
          await Future(() => _ffiService.stopVPN().cast<Utf8>().toDartString());
      if (result.isNotEmpty) {
        return left(Failure(error: result, localizedErrorMessage: ''));
      }
      appLogger.debug('startVPN result: $result');
      return right(result);
    } catch (e) {
      appLogger.error('Error while setting up radiance: $e');
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
    await setupRadiance();
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    // TODO: implement watchVPNStatus
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() {
    // TODO: implement isVPNConnected
    throw UnimplementedError();
  }
}
