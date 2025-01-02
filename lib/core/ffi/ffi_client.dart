// lib/core/ffi/ffi_client.dart

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';
//import 'package:lantern/core/ffi/socket_client.dart';

typedef StartVPNNative = Void Function();
typedef StartVPN = void Function();

typedef StopVPNNative = Void Function();
typedef StopVPN = void Function();

typedef IsVPNConnectedNative = Int32 Function();
typedef IsVPNConnectedDart = int Function();

const String _libName = 'liblantern';

class FFIClient {
  late DynamicLibrary _lib;

  late StartVPN startVPN;
  late StopVPN stopVPN;
  late IsVPNConnectedDart isVPNConnected;

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

    startVPN =
        _lib.lookup<NativeFunction<StartVPNNative>>('startVPN').asFunction();

    stopVPN =
        _lib.lookup<NativeFunction<StopVPNNative>>('stopVPN').asFunction();

    isVPNConnected = _lib
        .lookup<NativeFunction<IsVPNConnectedNative>>('isVPNConnected')
        .asFunction();
  }

  factory FFIClient() {
    return FFIClient._internal();
  }

  /// Calls the StartVPN function
  void start() {
    startVPN();
  }

  /// Calls the StopVPN function
  void stop() {
    stopVPN();
  }

  bool get isConnected {
    return isVPNConnected() == 1;
  }

  //Stream<bool> get vpnStatusStream => _socketClient.vpnStatusStream;
}
