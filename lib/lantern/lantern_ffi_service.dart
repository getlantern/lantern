import 'dart:ffi';
import 'dart:io';
export 'package:ffi/src/utf8.dart';
import 'package:ffi/ffi.dart';
import 'package:lantern/core/services/logger_service.dart';
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
  void startVPN() {
    // TODO: implement startVPN
  }

  @override
  void stopVPN() {
    // TODO: implement stopVPN
  }

  @override
  void setupRadiance() {
    try{
      appLogger.debug('Setting up radiance');
     final result =  _ffiService.setupRadiance(). cast<Utf8>().toDartString();
      appLogger.debug('Radiance setup result: $result');
    }catch(e){
      appLogger.error('Error while setting up radiance: $e');
    }

  }
}
