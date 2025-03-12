import 'dart:ffi';
import 'dart:io';

import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:path/path.dart' as p;

const String _libName = 'liblantern';

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
}
