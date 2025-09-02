import 'dart:ffi';
import 'package:ffi/ffi.dart';

final _kernel32 = DynamicLibrary.open('kernel32.dll');

typedef _WaitNamedPipeNative = Int32 Function(
    Pointer<Utf16> name, Uint32 timeoutMs);
typedef _WaitNamedPipeDart = int Function(Pointer<Utf16> name, int timeoutMs);

final _waitNamedPipeW =
    _kernel32.lookupFunction<_WaitNamedPipeNative, _WaitNamedPipeDart>(
  'WaitNamedPipeW',
);

bool waitNamedPipe(String pipeName, int timeoutMs) {
  final p = pipeName.toNativeUtf16();
  try {
    final ok = _waitNamedPipeW(p, timeoutMs);
    return ok != 0;
  } finally {
    calloc.free(p);
  }
}
