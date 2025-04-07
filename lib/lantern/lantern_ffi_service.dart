import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/app_data.dart';
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
  Stream<List<AppData>> appsDataStream() async* {
    final apps = <AppData>[];

    await for (final message in appsReceivePort) {
      try {
        if (message is String) {
          final List<dynamic> decoded = jsonDecode(message);
          final apps = decoded
              .map((json) => AppData.fromJson(json as Map<String, dynamic>))
              .toList();

          yield apps;
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

  @override
  Future<Either<Failure, String>> startVPN() {
    // TODO: implement startVPN
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    // TODO: implement stopVPN
    throw UnimplementedError();
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
