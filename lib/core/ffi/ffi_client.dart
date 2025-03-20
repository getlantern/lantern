// lib/core/ffi/ffi_client.dart

import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';

typedef StartVPNNative = Pointer<Utf8> Function();
typedef StartVPN = Pointer<Utf8> Function();

typedef StopVPNNative = Pointer<Utf8> Function();
typedef StopVPN = Pointer<Utf8> Function();

typedef SetupNative = Void Function(Pointer<Utf8>, Int64, Int64, Pointer<Void>);
typedef Setup = void Function(Pointer<Utf8>, int, int, Pointer<Void>);

typedef IsVPNConnectedNative = Int32 Function();
typedef IsVPNConnectedDart = int Function();

typedef FreeCStringNative = Void Function(Pointer<Utf8>);
typedef FreeCString = void Function(Pointer<Utf8>);

const String _libName = 'liblantern';

class FFIClient {
  late DynamicLibrary _lib;

  late StartVPN _startVPN;
  late StopVPN _stopVPN;
  late IsVPNConnectedDart isVPNConnected;
  late Setup _setup;
  late FreeCString _freeCString;

  final loggingReceivePort = ReceivePort();
  final appsReceivePort = ReceivePort();

  factory FFIClient(String dir) {
    return FFIClient._internal(dir);
  }

  FFIClient._internal(String dir) {
    if (Platform.isIOS) {
      _lib = DynamicLibrary.open('Liblantern.framework/Liblantern');
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('$_libName.dylib');
    } else if (Platform.isWindows) {
      _lib = DynamicLibrary.open('$_libName.dll');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    _startVPN =
        _lib.lookup<NativeFunction<StartVPNNative>>('startVPN').asFunction();

    _stopVPN =
        _lib.lookup<NativeFunction<StopVPNNative>>('stopVPN').asFunction();

    isVPNConnected = _lib
        .lookup<NativeFunction<IsVPNConnectedNative>>('isVPNConnected')
        .asFunction();

    _freeCString =
        _lib.lookupFunction<FreeCStringNative, FreeCString>('freeCString');

    _setup = _lib.lookupFunction<SetupNative, Setup>('setup');

    // configure logging
    final baseDirPtr = dir.toNativeUtf8();
    _setup(baseDirPtr, loggingReceivePort.sendPort.nativePort,
        appsReceivePort.sendPort.nativePort, NativeApi.initializeApiDLData);
    malloc.free(baseDirPtr);
  }

  Stream<String> logStream() async* {
    // Listen to messages sent by Go via Dart_PostCObject.
    await for (final message in loggingReceivePort) {
      if (message is String) {
        yield message;
      }
    }
  }

  Stream<AppData> appsDataStream() async* {
    await for (final message in appsReceivePort) {
      if (message is String) {
        AppData app = AppData.fromJson(jsonDecode(message));
        yield app;
      }
    }
  }

  // Calls startVPN and returns an error message if one exists.
  // Returns null if no error occurred.
  String? startVPN() {
    final Pointer<Utf8> result = _startVPN();
    if (result == nullptr) return null;
    final String errorMessage = result.toDartString();
    _freeCString(result);
    return errorMessage.isEmpty ? null : errorMessage;
  }

  // Calls stopVPN and returns an error message if one exists.
  // Returns null if no error occurred.
  String? stopVPN() {
    final Pointer<Utf8> result = _stopVPN();
    if (result == nullptr) return null;
    final String errorMessage = result.toDartString();
    _freeCString(result);
    return errorMessage.isEmpty ? null : errorMessage;
  }

  bool get isConnected {
    return isVPNConnected() == 1;
  }
}
