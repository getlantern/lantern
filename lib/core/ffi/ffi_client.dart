// lib/core/ffi/ffi_client.dart

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
//import 'package:lantern/core/ffi/socket_client.dart';

typedef StartVPNNative = Pointer<Utf8> Function();
typedef StartVPN = Pointer<Utf8> Function();

typedef StopVPNNative = Pointer<Utf8> Function();
typedef StopVPN = Pointer<Utf8> Function();

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
  late FreeCString _freeCString;

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

    _freeCString =
        _lib.lookupFunction<FreeCStringNative, FreeCString>('freeCString');
  }

  factory FFIClient() {
    return FFIClient._internal();
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
