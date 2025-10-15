import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:lantern/core/windows/utils.dart';
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

  Future<void> _getToken() async {
    if (token != null && token!.isNotEmpty) return;
    final programData =
        Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    final path = tokenPath ?? '$programData\\Lantern\\ipc-token';
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        token = (await File(path).readAsString()).trim();
        if (token!.isEmpty) throw Exception('IPC token file is empty: $path');
        return;
      } catch (_) {
        if (DateTime.now().isAfter(deadline)) {
          throw Exception('IPC token not found at $path');
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  Future<void> connect() async {
    await _getToken();
    _hPipe = openPipeBlocking(pipeName, timeoutMs);
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
    final pWritten = calloc<Uint32>();
    try {
      pBuf.asTypedList(bytes.length).setAll(0, bytes);
      final ok = WriteFile(_hPipe, pBuf, bytes.length, pWritten, nullptr);
      if (ok == 0) throw Exception('WriteFile failed: ${GetLastError()}');
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
      cancelAndClose(_hPipe);
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
          bufSize: bufSize,
          cmd: cmd,
          timeoutMs: timeoutMs,
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
      stopSend?.send(true);
      iso?.kill(priority: Isolate.beforeNextEvent);
      events.close();
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> watchStatus() {
    return _watchRaw('WatchStatus').transform(
      StreamTransformer.fromHandlers(handleData: (line, sink) {
        try {
          sink.add(jsonDecode(line) as Map<String, dynamic>);
        } catch (e, st) {
          sink.addError(e, st);
        }
      }),
    );
  }

  Stream<List<String>> watchLogs() {
    return _watchRaw('WatchLogs').transform(
      StreamTransformer.fromHandlers(handleData: (line, sink) {
        try {
          final obj = jsonDecode(line);
          if (obj is Map && obj['event'] == 'Logs') {
            final lines =
                (obj['lines'] as List?)?.cast<String>() ?? const <String>[];
            if (lines.isNotEmpty) sink.add(lines);
          }
        } catch (_) {}
      }),
    );
  }
}

class _WatchArgs {
  const _WatchArgs({
    required this.pipeName,
    required this.token,
    required this.bufSize,
    required this.cmd,
    required this.timeoutMs,
    required this.events,
  });
  final String pipeName;
  final String token;
  final int bufSize;
  final String cmd;
  final int timeoutMs;
  final SendPort events;
}

void _watchIsolateMain(_WatchArgs args) async {
  final stopPort = ReceivePort();
  args.events.send(stopPort.sendPort);

  int hPipe = INVALID_HANDLE_VALUE;

  String _watchReq(String token, String cmd) => '${jsonEncode({
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
            'cmd': cmd,
            'token': token,
          })}\n';

  try {
    hPipe = openPipeBlocking(args.pipeName, args.timeoutMs);

    final req = utf8.encode(_watchReq(args.token, args.cmd));
    final p = calloc<Uint8>(req.length);
    final w = calloc<Uint32>();
    try {
      p.asTypedList(req.length).setAll(0, req);
      final ok = WriteFile(hPipe, p, req.length, w, nullptr);
      if (ok == 0) {
        args.events.send({'error': 'WriteFile failed: ${GetLastError()}'});
        args.events.send(null);
        return;
      }
    } finally {
      free(w);
      free(p);
    }

    bool stopping = false;
    final stopSub = stopPort.listen((_) {
      stopping = true;
      CancelIoEx(hPipe, nullptr);
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
