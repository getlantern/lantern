import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class UnixHttpClient {
  UnixHttpClient({
    required this.socketPath,
    required this.token,
    this.basePath = '/',
  });

  final String socketPath;
  final String token;
  final String basePath;

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sock = await _connect();
    try {
      final payload = body == null ? '' : jsonEncode(body);
      final bytes = utf8.encode(payload);

      final req = StringBuffer()
        ..writeln('POST ${_join(basePath, path)} HTTP/1.1')
        ..writeln('Host: unix')
        ..writeln('Authorization: Bearer $token')
        ..writeln('Content-Type: application/json')
        ..writeln('Content-Length: ${bytes.length}')
        ..writeln('Connection: close')
        ..writeln();

      sock.add(utf8.encode(req.toString()));
      if (bytes.isNotEmpty) sock.add(bytes);

      final respBytes = await sock
          .fold<BytesBuilder>(BytesBuilder(), (b, data) => b..add(data))
          .timeout(timeout);

      final respStr = utf8.decode(respBytes.takeBytes());
      return _parseJsonHttpResponse(respStr);
    } finally {
      sock.destroy();
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sock = await _connect();
    try {
      final req = StringBuffer()
        ..writeln('GET ${_join(basePath, path)} HTTP/1.1')
        ..writeln('Host: unix')
        ..writeln('Authorization: Bearer $token')
        ..writeln('Connection: close')
        ..writeln();

      sock.add(utf8.encode(req.toString()));

      final respBytes = await sock
          .fold<BytesBuilder>(BytesBuilder(), (b, data) => b..add(data))
          .timeout(timeout);

      final respStr = utf8.decode(respBytes.takeBytes());
      return _parseJsonHttpResponse(respStr);
    } finally {
      sock.destroy();
    }
  }

  Future<Socket> _connect() {
    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    return Socket.connect(addr, 0);
  }

  String _join(String a, String b) {
    if (a.endsWith('/') && b.startsWith('/')) return a + b.substring(1);
    if (!a.endsWith('/') && !b.startsWith('/')) return '$a/$b';
    return a + b;
  }

  Map<String, dynamic> _parseJsonHttpResponse(String resp) {
    // Very small parser: split headers/body on first blank line.
    final sep = '\r\n\r\n';
    final idx = resp.indexOf(sep);
    final headerEnd = idx >= 0 ? idx + sep.length : resp.indexOf('\n\n') + 2;
    if (headerEnd <= 1) {
      throw StateError('Invalid HTTP response');
    }

    final headerText = resp.substring(0, headerEnd);
    final bodyText = resp.substring(headerEnd).trim();

    final statusLine = headerText.split('\n').first.trim();
    final m = RegExp(r'^HTTP/\d\.\d\s+(\d{3})').firstMatch(statusLine);
    final code = m == null ? 0 : int.parse(m.group(1)!);

    if (code < 200 || code >= 300) {
      // If server returned plaintext error, surface it.
      throw HttpException(
          'HTTP $code: ${bodyText.isEmpty ? statusLine : bodyText}');
    }

    if (bodyText.isEmpty) return <String, dynamic>{};
    final obj = jsonDecode(bodyText);
    if (obj is Map<String, dynamic>) return obj;
    throw StateError('Expected JSON object response');
  }
}
