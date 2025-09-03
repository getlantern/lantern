// lib/core/windows/radiance_ipc_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Minimal HTTP over Windows named pipe, dedicated to Radiance IPC
class _PipeHttpClient {
  _PipeHttpClient(
      {this.pipePath = r'\\.\pipe\Lantern\radiance',
      this.timeoutMs = 3000,
      this.bufSize = 256 * 1024});

  final String pipePath;
  final int timeoutMs;
  final int bufSize;

  int _hPipe = INVALID_HANDLE_VALUE;

  Future<void> _connect() async {
    final start = DateTime.now();
    final lpName = TEXT(pipePath);
    try {
      while (true) {
        _hPipe = CreateFile(lpName, GENERIC_READ | GENERIC_WRITE, 0, nullptr,
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
        if (_hPipe != INVALID_HANDLE_VALUE) return;

        final last = GetLastError();
        if (last == ERROR_PIPE_BUSY) {
          if (DateTime.now().difference(start).inMilliseconds >= timeoutMs) {
            throw Exception('Timed out waiting for radiance pipe');
          }
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }
        throw Exception('CreateFile failed: $last');
      }
    } finally {
      free(lpName);
    }
  }

  Future<void> _close() async {
    if (_hPipe != INVALID_HANDLE_VALUE) {
      CloseHandle(_hPipe);
      _hPipe = INVALID_HANDLE_VALUE;
    }
  }

  Future<_HttpResponse> request(String method, String path,
      {Object? jsonBody}) async {
    await _connect();
    try {
      final body = jsonBody == null
          ? Uint8List(0)
          : Uint8List.fromList(utf8.encode(jsonEncode(jsonBody)));
      final headers = StringBuffer()
        ..write('$method $path HTTP/1.1\r\n')
        ..write('Host: pipe\r\n')
        ..write('Connection: close\r\n');
      if (body.isNotEmpty) {
        headers
          ..write('Content-Type: application/json\r\n')
          ..write('Content-Length: ${body.length}\r\n');
      }
      headers.write('\r\n');

      final headBytes = Uint8List.fromList(utf8.encode(headers.toString()));
      _writeAll(headBytes);
      if (body.isNotEmpty) _writeAll(body);

      final respBytes = _readAll();

      return _HttpResponse.parse(respBytes);
    } finally {
      await _close();
    }
  }

  void _writeAll(Uint8List data) {
    final p = calloc<Uint8>(data.length);
    final w = calloc<Uint32>();
    try {
      p.asTypedList(data.length).setAll(0, data);
      final ok = WriteFile(_hPipe, p, data.length, w, nullptr);
      if (ok == 0) {
        throw Exception('WriteFile failed: ${GetLastError()}');
      }
    } finally {
      free(w);
      free(p);
    }
  }

  Uint8List _readAll() {
    final p = calloc<Uint8>(bufSize);
    final r = calloc<Uint32>();
    final bldr = BytesBuilder(copy: false);
    try {
      while (true) {
        final ok = ReadFile(_hPipe, p, bufSize, r, nullptr);
        if (ok == 0) {
          final err = GetLastError();
          if (err == ERROR_BROKEN_PIPE) break;
          throw Exception('ReadFile failed: $err');
        }
        final n = r.value;
        if (n == 0) continue;
        bldr.add(Uint8List.sublistView(p.asTypedList(n)));
      }
      return bldr.takeBytes();
    } finally {
      free(r);
      free(p);
    }
  }
}

class _HttpResponse {
  _HttpResponse(this.statusCode, this.headers, this.body);
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;

  static _HttpResponse parse(Uint8List raw) {
    final sep = _indexOfSequence(raw, _crlfcrlf);
    if (sep < 0)
      throw Exception('Invalid HTTP response (no header/body separator)');
    final head = utf8.decode(raw.sublist(0, sep));
    final body = raw.sublist(sep + 4);

    final lines = const LineSplitter().convert(head);
    if (lines.isEmpty || !lines.first.startsWith('HTTP/'))
      throw Exception('Invalid status line');
    final status = int.parse(lines.first.split(' ')[1]);

    final hdrs = <String, String>{};
    for (var i = 1; i < lines.length; i++) {
      final ln = lines[i];
      final idx = ln.indexOf(':');
      if (idx <= 0) continue;
      hdrs[ln.substring(0, idx).trim().toLowerCase()] =
          ln.substring(idx + 1).trim();
    }

    Uint8List finalBody = body;

    if ((hdrs['transfer-encoding'] ?? '').toLowerCase().contains('chunked')) {
      finalBody = _dechunk(body);
    } else if (hdrs.containsKey('content-length')) {
      final want = int.tryParse(hdrs['content-length']!) ?? body.length;
      if (want <= body.length) {
        finalBody = Uint8List.sublistView(body, 0, want);
      }
    }

    return _HttpResponse(status, hdrs, finalBody);
  }

  static Uint8List _dechunk(Uint8List chunked) {
    int i = 0;
    final out = BytesBuilder(copy: false);
    while (true) {
      // read size line (hex) ending with CRLF
      final lineEnd = _indexOfSequenceFrom(chunked, _crlf, i);
      if (lineEnd < 0) throw Exception('Malformed chunk (no size CRLF)');
      final sizeStr =
          utf8.decode(chunked.sublist(i, lineEnd)).split(';')[0].trim();
      final size = int.parse(sizeStr, radix: 16);
      i = lineEnd + 2;
      if (size == 0) {
        break;
      }
      if (i + size > chunked.length)
        throw Exception('Malformed chunk (size beyond end)');
      out.add(Uint8List.sublistView(chunked, i, i + size));
      i += size;
      if (!(i + 1 < chunked.length &&
          chunked[i] == 13 &&
          chunked[i + 1] == 10)) {
        throw Exception('Malformed chunk (missing CRLF)');
      }
      i += 2;
    }
    return out.takeBytes();
  }

  static const _crlf = [13, 10];
  static const _crlfcrlf = [13, 10, 13, 10];

  static int _indexOfSequence(Uint8List data, List<int> pat) =>
      _indexOfSequenceFrom(data, pat, 0);

  static int _indexOfSequenceFrom(Uint8List data, List<int> pat, int from) {
    for (var i = from; i <= data.length - pat.length; i++) {
      var j = 0;
      for (; j < pat.length; j++) {
        if (data[i + j] != pat[j]) break;
      }
      if (j == pat.length) return i;
    }
    return -1;
  }
}

class RadianceIPC {
  RadianceIPC({String? pipe})
      : _client =
            _PipeHttpClient(pipePath: pipe ?? r'\\.\pipe\Lantern\radiance');

  final _PipeHttpClient _client;

  Future<String> status() async {
    final resp = await _client.request('GET', '/status');
    if (resp.statusCode != 200)
      throw Exception('status: HTTP ${resp.statusCode}');
    final m = jsonDecode(utf8.decode(resp.body)) as Map<String, dynamic>;
    return (m['state'] as String?) ?? 'closed';
  }

  Future<void> setMode(String mode) async {
    final resp =
        await _client.request('POST', '/clash/mode', jsonBody: {'mode': mode});
    if (resp.statusCode != 200)
      throw Exception('setMode: HTTP ${resp.statusCode}');
  }

  Future<void> select(String groupTag, String outboundTag) async {
    final resp = await _client.request('POST', '/outbound/select',
        jsonBody: {'groupTag': groupTag, 'outboundTag': outboundTag});
    if (resp.statusCode != 200)
      throw Exception('select: HTTP ${resp.statusCode}');
  }

  Future<void> closeService() async {
    final resp = await _client.request('POST', '/service/close');
    if (resp.statusCode != 200)
      throw Exception('closeService: HTTP ${resp.statusCode}');
  }

  Stream<String> watchStatus(
      {Duration interval = const Duration(milliseconds: 900)}) async* {
    String? last;
    while (true) {
      try {
        final s = await status();
        final mapped = (s == 'running') ? 'Connected' : 'Disconnected';
        if (mapped != last) {
          last = mapped;
          yield mapped;
        }
      } catch (_) {
        if (last != 'Disconnected') {
          last = 'Disconnected';
          yield last!;
        }
      }
      await Future.delayed(interval);
    }
  }
}
