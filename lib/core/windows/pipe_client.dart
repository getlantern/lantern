import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:lantern/core/windows/wait_named_pipe.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

class PipeClient {
  PipeClient({
    this.pipeName = r'\\.\pipe\LanternService',
    this.token,
    this.tokenPath,
    this.timeoutMs = 3000,
    this.bufSize = 64 * 1024,
  });

  final String pipeName;
  String? token;
  final String? tokenPath;
  final int timeoutMs;
  final int bufSize;

  int _hPipe = INVALID_HANDLE_VALUE;
  bool get isConnected => _hPipe != INVALID_HANDLE_VALUE;

  Future<void> _getToken({int? maxWaitMs}) async {
    if (token != null && token!.isNotEmpty) return;
    final programData =
        Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    final path = tokenPath ?? '$programData\\Lantern\\ipc-token';

    final total = (maxWaitMs ?? timeoutMs);
    final deadline = DateTime.now().add(Duration(milliseconds: total));
    while (true) {
      try {
        final s = await File(path).readAsString();
        token = s.trim();
        if (token!.isEmpty) {
          throw Exception('IPC token file is empty: $path');
        }
        return;
      } catch (e) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('Timed out waiting for IPC token at $path');
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> connect() async {
    final total = timeoutMs < 10000 ? 10000 : timeoutMs;
    final deadline = DateTime.now().add(Duration(milliseconds: total));
    final lpName = TEXT(pipeName);

    try {
      while (true) {
        final remaining = deadline.difference(DateTime.now()).inMilliseconds;
        if (remaining <= 0) {
          throw Exception('Timed out waiting for pipe "$pipeName"');
        }
        if (waitNamedPipe(pipeName, remaining)) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final remainingForToken =
          deadline.difference(DateTime.now()).inMilliseconds;
      await _getToken(maxWaitMs: remainingForToken > 0 ? remainingForToken : 1);

      while (true) {
        _hPipe = CreateFile(lpName, GENERIC_READ | GENERIC_WRITE, 0, nullptr,
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
        if (_hPipe != INVALID_HANDLE_VALUE) {
          final mode = calloc<Uint32>()..value = PIPE_READMODE_MESSAGE;
          try {
            SetNamedPipeHandleState(_hPipe, mode, nullptr, nullptr);
          } finally {
            calloc.free(mode);
          }
          return;
        }

        final err = GetLastError();
        final remaining = deadline.difference(DateTime.now()).inMilliseconds;
        if (remaining <= 0) {
          throw Exception('Timed out opening pipe, last error=$err');
        }
        if (err == ERROR_PIPE_BUSY || err == ERROR_FILE_NOT_FOUND) {
          waitNamedPipe(pipeName, remaining);
          continue;
        }
        throw Exception('Failed to open pipe: error $err');
      }
    } finally {
      free(lpName);
    }
  }

  Future<Map<String, dynamic>> call(String cmd,
      [Map<String, dynamic>? params]) async {
    if (!isConnected) throw StateError('Pipe not connected');

    await _getToken();

    final payload = '${jsonEncode({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'cmd': cmd,
          'token': token,
          if (params != null) 'params': params,
        })}\n';

    final bytes = utf8.encode(payload);
    final pBuf = calloc<Uint8>(bytes.length);
    try {
      final asList = pBuf.asTypedList(bytes.length);
      asList.setAll(0, bytes);

      final written = calloc<Uint32>();
      try {
        final ok = WriteFile(_hPipe, pBuf, bytes.length, written, nullptr);
        if (ok == 0) throw Exception('WriteFile failed: ${GetLastError()}');
      } finally {
        free(written);
      }
    } finally {
      free(pBuf);
    }

    return _readOneJsonLine();
  }

  Map<String, dynamic> _parse(Map<String, dynamic> resp) {
    final err = resp['error'];
    if (err != null) {
      final e = err as Map<String, dynamic>;
      throw Exception('${e['code']}: ${e['message']}');
    }
    final result = resp['result'];
    return (result is Map<String, dynamic>)
        ? result
        : <String, dynamic>{'value': result};
  }

  Map<String, dynamic> _decode(String s) =>
      _parse(jsonDecode(s) as Map<String, dynamic>);

  Future<Map<String, dynamic>> _readOneJsonLine() async {
    final pBuf = calloc<Uint8>(bufSize);
    final pRead = calloc<Uint32>();
    final bldr = BytesBuilder();
    try {
      while (true) {
        final ok = ReadFile(_hPipe, pBuf, bufSize, pRead, nullptr);
        if (ok == 0) throw Exception('ReadFile failed: ${GetLastError()}');
        final n = pRead.value;
        if (n == 0) continue;
        final chunk = Uint8List.sublistView(pBuf.asTypedList(n));
        final nl = chunk.indexOf(0x0A);
        if (nl >= 0) {
          bldr.add(chunk.sublist(0, nl));
          break;
        }
        bldr.add(chunk);
      }
      return _decode(utf8.decode(bldr.takeBytes()));
    } finally {
      free(pBuf);
      free(pRead);
    }
  }

  Future<void> close() async {
    if (_hPipe != INVALID_HANDLE_VALUE) {
      CloseHandle(_hPipe);
      _hPipe = INVALID_HANDLE_VALUE;
    }
  }

  Future<Stream<Map<String, dynamic>>> watchStatus() async {
    if (!isConnected) {
      await connect();
    }
    await _getToken();

    final payload = '${jsonEncode({
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'cmd': 'WatchStatus',
          'token': token,
        })}\n';

    final bytes = utf8.encode(payload);
    final pBuf = calloc<Uint8>(bytes.length);
    final written = calloc<Uint32>();
    try {
      pBuf.asTypedList(bytes.length).setAll(0, bytes);
      final ok = WriteFile(_hPipe, pBuf, bytes.length, written, nullptr);
      if (ok == 0) {
        throw Exception('WriteFile failed: ${GetLastError()}');
      }
    } finally {
      free(written);
      free(pBuf);
    }

    final controller =
        StreamController<Map<String, dynamic>>(onCancel: () async {
      await close();
    });

    // Reader loop
    () async {
      final pBuf = calloc<Uint8>(bufSize);
      final pRead = calloc<Uint32>();
      final bldr = BytesBuilder();
      try {
        while (true) {
          final ok = ReadFile(_hPipe, pBuf, bufSize, pRead, nullptr);
          if (ok == 0) {
            controller
                .addError(Exception('ReadFile failed: ${GetLastError()}'));
            break;
          }
          final n = pRead.value;
          if (n == 0) continue;
          final chunk = Uint8List.sublistView(pBuf.asTypedList(n));
          final nl = chunk.indexOf(0x0A);
          if (nl >= 0) {
            bldr.add(chunk.sublist(0, nl));
            final line = utf8.decode(bldr.takeBytes());
            controller.add(jsonDecode(line) as Map<String, dynamic>);
            if (nl + 1 < chunk.length) {
              bldr.add(chunk.sublist(nl + 1));
            }
          } else {
            bldr.add(chunk);
          }
        }
      } catch (e, _) {
        controller.addError(e);
      } finally {
        free(pBuf);
        free(pRead);
        await controller.close();
      }
    }();

    return controller.stream;
  }
}
