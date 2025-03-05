// lib/core/ffi/ffi_client.dart

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'package:ffi/ffi.dart';
//import 'package:lantern/core/ffi/socket_client.dart';

typedef StartVPNNative = Pointer<Utf8> Function();
typedef StartVPN = Pointer<Utf8> Function();

typedef StopVPNNative = Pointer<Utf8> Function();
typedef StopVPN = Pointer<Utf8> Function();

typedef SetupNative = Void Function(Pointer<Void>);
typedef Setup = void Function(Pointer<Void>);

typedef IsVPNConnectedNative = Int32 Function();
typedef IsVPNConnectedDart = int Function();

typedef SetLogPortC = Void Function(Int64 port);
typedef SetLogPortDart = void Function(int port);

typedef FreeCStringNative = Void Function(Pointer<Utf8>);
typedef FreeCString = void Function(Pointer<Utf8>);

const String _libName = 'liblantern';

class FFIClient {
  late DynamicLibrary _lib;

  late StartVPN _startVPN;
  late StopVPN _stopVPN;
  late IsVPNConnectedDart isVPNConnected;
  late SetLogPortDart _setLogPort;
  late Setup _setup;
  late FreeCString _freeCString;

  factory FFIClient() {
    return FFIClient._internal();
  }

  FFIClient._internal() {
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

    _setLogPort =
        _lib.lookupFunction<SetLogPortC, SetLogPortDart>("setLogPort");

    _freeCString =
        _lib.lookupFunction<FreeCStringNative, FreeCString>('freeCString');

    _setup = _lib.lookupFunction<SetupNative, Setup>('setup');
    _setup(NativeApi.initializeApiDLData);
  }

  Stream<String> logStream() async* {
    final receivePort = ReceivePort();

    // Pass the native port to the Go side.
    _setLogPort(receivePort.sendPort.nativePort);

    // Listen to messages sent by Go via Dart_PostCObject.
    await for (final message in receivePort) {
      if (message is String) {
        yield message;
      }
    }
  }

  /// Calls startVPN and returns an error message if one exists.
  /// Returns null if no error occurred.
  String? startVPN() {
    final Pointer<Utf8> result = _startVPN();
    if (result == nullptr) return null;
    final String errorMessage = result.toDartString();
    _freeCString(result);
    return errorMessage.isEmpty ? null : errorMessage;
  }

  /// Calls stopVPN and returns an error message if one exists.
  /// Returns null if no error occurred.
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
  //Stream<bool> get vpnStatusStream => _socketClient.vpnStatusStream;
}
