import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

typedef _WaitNamedPipeWNative = Int32 Function(
    Pointer<Utf16> lpName, Uint32 timeoutMs);
typedef _WaitNamedPipeWDart = int Function(
    Pointer<Utf16> lpName, int timeoutMs);
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final _WaitNamedPipeWDart _WaitNamedPipeW =
    _kernel32.lookupFunction<_WaitNamedPipeWNative, _WaitNamedPipeWDart>(
        'WaitNamedPipeW');

int openPipeBlocking(String fullName, int timeoutMs) {
  final start = DateTime.now();
  final lpName = TEXT(fullName);
  try {
    while (true) {
      final h = CreateFile(
        lpName,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        0,
      );
      if (h != INVALID_HANDLE_VALUE) {
        final mode = calloc<Uint32>()..value = PIPE_READMODE_MESSAGE;
        final ok = SetNamedPipeHandleState(h, mode, nullptr, nullptr);
        free(mode);
        if (ok == 0) {
          final code = GetLastError();
          CloseHandle(h);
          throw Exception('SetNamedPipeHandleState failed: $code');
        }
        return h;
      }

      final code = GetLastError();

      if (code == ERROR_FILE_NOT_FOUND || code == ERROR_PIPE_BUSY) {
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        if (elapsed >= timeoutMs) {
          throw Exception('Timed out waiting for pipe ($code)');
        }
        final remain = timeoutMs - elapsed;
        _WaitNamedPipeW(lpName, remain < 200 ? remain : 200);
        continue;
      }

      throw Exception('Failed to open pipe: error $code');
    }
  } finally {
    free(lpName);
  }
}

void cancelAndClose(int h) {
  if (h != INVALID_HANDLE_VALUE) {
    CancelIoEx(h, nullptr);
    CloseHandle(h);
  }
}
