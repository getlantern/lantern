import 'dart:async';
import 'dart:convert';
import 'dart:io';

class UnixSocketClient {
  UnixSocketClient({
    required this.socketPath,
    required this.token,
  });

  final String socketPath;
  final String token;

  Socket? _sock;
  StreamSubscription<String>? _sub;
  final _pending = <String, Completer<Map<String, dynamic>>>{};

  Future<void> connect() async {
    if (_sock != null) return;

    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    _sock = await Socket.connect(addr, 0);

    // Socket is Stream<Uint8List>. utf8.decoder expects Stream<List<int>>
    final lines = const LineSplitter().bind(
      utf8.decoder.bind(_sock!.cast<List<int>>()),
    );

    _sub = lines.listen(
      _onLine,
      onError: (e, st) {
        for (final c in _pending.values) {
          if (!c.isCompleted) c.completeError(e, st);
        }
        _pending.clear();
      },
      onDone: () {
        for (final c in _pending.values) {
          if (!c.isCompleted) c.completeError(StateError('socket closed'));
        }
        _pending.clear();
      },
      cancelOnError: true,
    );
  }

  Future<void> close() async {
    await _sub?.cancel();
    _sub = null;
    _sock?.destroy();
    _sock = null;
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    final obj = jsonDecode(line);
    if (obj is! Map<String, dynamic>) return;

    final id = obj['id'] as String?;
    if (id == null) return;

    final c = _pending.remove(id);
    if (c != null && !c.isCompleted) {
      c.complete(obj);
    }
  }

  String _newId() => 'r_${DateTime.now().microsecondsSinceEpoch}';

  Future<Map<String, dynamic>> call(String cmd,
      [Map<String, dynamic>? params]) async {
    await connect();

    final id = _newId();
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;

    final req = <String, dynamic>{
      'id': id,
      'cmd': cmd,
      'token': token,
      if (params != null) 'params': params,
    };

    _sock!.write('${jsonEncode(req)}\n');
    return c.future.timeout(const Duration(seconds: 10));
  }

  Stream<Map<String, dynamic>> watch(String cmd) async* {
    final addr = InternetAddress(socketPath, type: InternetAddressType.unix);
    final sock = await Socket.connect(addr, 0);

    final req = {
      'id': _newId(),
      'cmd': cmd,
      'token': token,
    };
    sock.write('${jsonEncode(req)}\n');

    final lines = const LineSplitter().bind(
      utf8.decoder.bind(sock.cast<List<int>>()),
    );

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final obj = jsonDecode(line);
      if (obj is Map<String, dynamic>) yield obj;
    }
  }
}
