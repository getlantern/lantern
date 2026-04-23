import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:lantern/core/common/common.dart';
import 'package:win32/win32.dart';

class PipeClient {
  PipeClient({
    this.pipeName = r'\\.\pipe\LanternService',
    this.token,
    this.tokenPath,
    this.timeoutMs = 3000,
    this.tokenWaitMs = 5000,
    this.bufSize = 64 * 1024,
  });

  final String pipeName;
  String? token;
  final String? tokenPath;
  final int timeoutMs;
  final int tokenWaitMs;
  final int bufSize;
  final Random _jitter = Random();

  int _retryFailureStreak = 0;
  DateTime? _lastRetryFailureAt;

  int _hPipe = INVALID_HANDLE_VALUE;

  bool get isConnected => _hPipe != INVALID_HANDLE_VALUE;

  Future<void> _getToken() async {
    if (token != null && token!.isNotEmpty) return;
    final programData =
        Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    final path = tokenPath ?? '$programData\\Lantern\\ipc-token';
    final deadline = DateTime.now().add(Duration(milliseconds: tokenWaitMs));
    PipeTokenErrorKind failureKind = PipeTokenErrorKind.missing;
    String failureDetail = 'IPC token file not found at $path';
    while (true) {
      try {
        final currentToken = (await File(path).readAsString()).trim();
        if (currentToken.isEmpty) {
          failureKind = PipeTokenErrorKind.empty;
          failureDetail = 'IPC token file is empty at $path';
        } else {
          token = currentToken;
          return;
        }
      } on FileSystemException catch (e) {
        final errorCode = e.osError?.errorCode;
        if (errorCode == ERROR_FILE_NOT_FOUND ||
            errorCode == ERROR_PATH_NOT_FOUND) {
          failureKind = PipeTokenErrorKind.missing;
        } else {
          failureKind = PipeTokenErrorKind.unreadable;
        }
        failureDetail = e.toString();
      } catch (e) {
        failureKind = PipeTokenErrorKind.unreadable;
        failureDetail = e.toString();
      }
      if (DateTime.now().isAfter(deadline)) {
        throw PipeTokenException(
          path: path,
          kind: failureKind,
          waitedMs: tokenWaitMs,
          detail: failureDetail,
        );
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> connect() async {
    await _getToken();
    if (isConnected) {
      await close();
    }
    _hPipe = await _openPipeHandle(pipeName, timeoutMs);
  }

  Future<Map<String, dynamic>> call(
    String cmd, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      await _connectPipeIfNeeded();
      final response = await _callConnected(cmd, params);
      _resetRetryWindow();
      return response;
    } catch (e) {
      if (_isAuthOrTokenError(e)) {
        appLogger.warning(
          'Pipe call failed with auth/token error; clearing cached token: $e',
        );
        await _resetConnectionState(clearToken: true);
        rethrow;
      }
      if (!_isRecoverablePipeTransportError(e)) {
        rethrow;
      }
      final delay = _nextRetryDelay();
      appLogger.warning(
        'Pipe transport failure, reconnecting once in '
        '${delay.inMilliseconds}ms: $e',
      );
      await Future.delayed(delay);
      await _resetConnectionState(clearToken: false);
      await _connectPipeIfNeeded();
      try {
        final response = await _callConnected(cmd, params);
        _resetRetryWindow();
        return response;
      } catch (retryError) {
        if (_isAuthOrTokenError(retryError)) {
          appLogger.warning(
            'Reconnect retry hit auth/token error; clearing cached token: '
            '$retryError',
          );
          await _resetConnectionState(clearToken: true);
        }
        rethrow;
      }
    }
  }

  Future<void> _connectPipeIfNeeded() async {
    if (isConnected) {
      return;
    }
    await connect();
  }

  Future<void> _resetConnectionState({required bool clearToken}) async {
    await close();
    if (clearToken) {
      token = null;
    }
  }

  bool _isRecoverablePipeTransportError(Object e) {
    if (e is PipeTransportException) {
      const recoverable = <int>{
        ERROR_BROKEN_PIPE,
        ERROR_PIPE_NOT_CONNECTED,
        ERROR_NO_DATA,
        ERROR_INVALID_HANDLE,
        ERROR_PIPE_BUSY,
        ERROR_FILE_NOT_FOUND,
        ERROR_PATH_NOT_FOUND,
        0,
      };
      return recoverable.contains(e.code);
    }
    return false;
  }

  bool _isAuthOrTokenError(Object e) {
    if (e is PipeTokenException) {
      return true;
    }
    if (e is PipeRpcException) {
      final code = e.code.toLowerCase();
      if (code == 'unauthorized' || code == 'invalid_token') {
        return true;
      }
      final message = e.message.toLowerCase();
      return message.contains('token') || message.contains('unauthorized');
    }
    return false;
  }

  Duration _nextRetryDelay() {
    final now = DateTime.now();
    if (_lastRetryFailureAt == null ||
        now.difference(_lastRetryFailureAt!) > const Duration(seconds: 5)) {
      _retryFailureStreak = 0;
    }
    _lastRetryFailureAt = now;
    _retryFailureStreak += 1;

    const baseMs = 120;
    const maxBackoffMs = 2000;
    var exponent = _retryFailureStreak - 1;
    if (exponent < 0) {
      exponent = 0;
    } else if (exponent > 5) {
      exponent = 5;
    }
    final exponentialMs = baseMs * (1 << exponent);
    final cappedMs = min(exponentialMs, maxBackoffMs);
    final jitterMs = 40 + _jitter.nextInt(161);
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  void _resetRetryWindow() {
    _retryFailureStreak = 0;
    _lastRetryFailureAt = null;
  }

  Future<Map<String, dynamic>> _callConnected(
    String cmd,
    Map<String, dynamic>? params,
  ) async {
    await _getToken();
    final request = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'cmd': cmd,
      'token': token,
    };
    if (params != null) {
      request['params'] = params;
    }
    final payload = '${jsonEncode(request)}\n';

    final bytes = utf8.encode(payload);
    final pBuf = calloc<Uint8>(bytes.length);
    final pWritten = calloc<Uint32>();
    try {
      pBuf.asTypedList(bytes.length).setAll(0, bytes);
      final ok = WriteFile(_hPipe, pBuf, bytes.length, pWritten, nullptr);
      if (ok == 0) {
        throw PipeTransportException(
          operation: 'WriteFile',
          code: GetLastError(),
        );
      }
    } finally {
      free(pWritten);
      free(pBuf);
    }

    return _readOneJsonLine();
  }

  Map<String, dynamic> _parse(Map<String, dynamic> resp) {
    final err = resp['error'];
    if (err != null) {
      final e = err as Map<String, dynamic>;
      throw PipeRpcException(
        code: e['code']?.toString() ?? 'rpc_error',
        message: e['message']?.toString() ?? 'unknown rpc error',
      );
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
        if (ok == 0) {
          throw PipeTransportException(
            operation: 'ReadFile',
            code: GetLastError(),
          );
        }
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

  Stream<String> _watchRaw(String cmd) {
    final controller = StreamController<String>.broadcast();
    final events = ReceivePort();
    Isolate? iso;
    SendPort? stopSend;

    controller.onListen = () async {
      await _getToken();

      iso = await Isolate.spawn<_WatchArgs>(
        _watchIsolateMain,
        _WatchArgs(
          pipeName: pipeName,
          token: token!,
          timeoutMs: timeoutMs,
          bufSize: bufSize,
          cmd: cmd,
          events: events.sendPort,
        ),
        debugName: 'pipe-watch-$cmd',
      );

      events.listen((msg) {
        if (msg is SendPort) {
          stopSend = msg;
          return;
        }
        if (msg == null) {
          appLogger.info('Pipe watch $cmd ended - closing stream');
          controller.close();
          return;
        }
        if (msg is String) {
          controller.add(msg);
          return;
        }
        if (msg is Map) {
          final err = msg['error'];
          if (err is String) controller.addError(Exception(err));
        }
      });
    };

    controller.onCancel = () async {
      appLogger.info('Pipe watch $cmd cancelled - closing stream');
      stopSend?.send(true);
      iso?.kill(priority: Isolate.beforeNextEvent);
      events.close();
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> watchStatus() {
    return _watchRaw('WatchStatus').transform(
      StreamTransformer.fromHandlers(
        handleData: (line, sink) {
          try {
            sink.add(jsonDecode(line) as Map<String, dynamic>);
          } catch (e, st) {
            sink.addError(e, st);
          }
        },
      ),
    );
  }

  Stream<List<String>> watchLogs() {
    return _watchRaw('WatchLogs').transform(
      StreamTransformer.fromHandlers(
        handleData: (line, sink) {
          try {
            final obj = jsonDecode(line);
            if (obj is Map && obj['event'] == 'Logs') {
              final lines =
                  (obj['lines'] as List?)?.cast<String>() ?? const <String>[];
              if (lines.isNotEmpty) sink.add(lines);
            }
          } catch (e) {
            appLogger.error('[PipeClient] failed to parse pipe line: $line', e);
          }
        },
        handleError: (e, st, sink) {
          appLogger.error('[PipeClient] watchLogs stream error', e, st);
          sink.addError(e, st);
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
  }
}

class PipeTransportException implements Exception {
  const PipeTransportException({
    required this.operation,
    required this.code,
    this.timedOut = false,
  });

  final String operation;
  final int code;
  final bool timedOut;

  @override
  String toString() {
    final hex = '0x${code.toRadixString(16)}';
    if (timedOut) {
      return '$operation timed out (last error: $code/$hex)';
    }
    return '$operation failed: $code ($hex)';
  }
}

class PipeRpcException implements Exception {
  const PipeRpcException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

enum PipeTokenErrorKind { missing, empty, unreadable }

class PipeTokenException implements Exception {
  const PipeTokenException({
    required this.path,
    required this.kind,
    required this.waitedMs,
    required this.detail,
  });

  final String path;
  final PipeTokenErrorKind kind;
  final int waitedMs;
  final String detail;

  @override
  String toString() {
    final kindText = switch (kind) {
      PipeTokenErrorKind.missing => 'missing',
      PipeTokenErrorKind.empty => 'empty',
      PipeTokenErrorKind.unreadable => 'unreadable',
    };
    return 'IPC token $kindText after ${waitedMs}ms at $path: $detail';
  }
}

class _WatchArgs {
  const _WatchArgs({
    required this.pipeName,
    required this.token,
    required this.timeoutMs,
    required this.bufSize,
    required this.cmd,
    required this.events,
  });
  final String pipeName;
  final String token;
  final int timeoutMs;
  final int bufSize;
  final String cmd;
  final SendPort events;
}

void _watchIsolateMain(_WatchArgs args) async {
  final stopPort = ReceivePort();
  args.events.send(stopPort.sendPort);

  int hPipe = INVALID_HANDLE_VALUE;

  String watchReq(String token, String cmd) =>
      '${jsonEncode({'id': DateTime.now().microsecondsSinceEpoch.toString(), 'cmd': cmd, 'token': token})}\n';

  try {
    try {
      hPipe = await _openPipeHandle(args.pipeName, args.timeoutMs);
    } on PipeTransportException catch (e) {
      args.events.send({'error': e.toString()});
      return;
    }

    final req = utf8.encode(watchReq(args.token, args.cmd));
    final p = calloc<Uint8>(req.length);
    final w = calloc<Uint32>();
    try {
      p.asTypedList(req.length).setAll(0, req);
      final ok = WriteFile(hPipe, p, req.length, w, nullptr);
      if (ok == 0) {
        args.events.send({'error': 'WriteFile failed: ${GetLastError()}'});
        return;
      }
    } finally {
      free(w);
      free(p);
    }

    bool stopping = false;
    final stopSub = stopPort.listen((_) {
      stopping = true;
      if (hPipe != INVALID_HANDLE_VALUE) {
        CloseHandle(hPipe);
        hPipe = INVALID_HANDLE_VALUE;
      }
      stopPort.close();
    });

    final buf = calloc<Uint8>(args.bufSize);
    final r = calloc<Uint32>();
    String carry = '';
    try {
      while (!stopping) {
        final ok = ReadFile(hPipe, buf, args.bufSize, r, nullptr);
        if (ok == 0) break;
        final n = r.value;
        if (n == 0) continue;

        final s = utf8.decode(Uint8List.sublistView(buf.asTypedList(n)));
        final combined = carry + s;
        final parts = combined.split('\n');
        for (var i = 0; i < parts.length - 1; i++) {
          final line = parts[i];
          if (line.isEmpty) continue;
          // send raw JSON line back
          args.events.send(line);
        }
        carry = parts.isNotEmpty ? parts.last : '';
      }
    } finally {
      stopSub.cancel();
      free(buf);
      free(r);
    }
  } catch (e) {
    args.events.send({'error': e.toString()});
  } finally {
    if (hPipe != INVALID_HANDLE_VALUE) {
      CloseHandle(hPipe);
    }
    args.events.send(null);
  }
}

bool _isRetryablePipeOpenError(int code) {
  return code == ERROR_PIPE_BUSY ||
      code == ERROR_FILE_NOT_FOUND ||
      code == ERROR_PATH_NOT_FOUND ||
      code == 0;
}

Future<int> _openPipeHandle(String pipeName, int timeoutMs) async {
  final start = DateTime.now();
  final lpName = TEXT(pipeName);
  try {
    while (true) {
      final handle = CreateFile(
        lpName,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        0,
      );
      if (handle != INVALID_HANDLE_VALUE) {
        return handle;
      }

      final code = GetLastError();
      if (_isRetryablePipeOpenError(code)) {
        if (DateTime.now().difference(start).inMilliseconds >= timeoutMs) {
          throw PipeTransportException(
            operation: 'Open pipe',
            code: code,
            timedOut: true,
          );
        }
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      throw PipeTransportException(operation: 'Open pipe', code: code);
    }
  } finally {
    free(lpName);
  }
}
