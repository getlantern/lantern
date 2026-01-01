import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/linux/unix_socket_client.dart';
import 'package:lantern/core/models/lantern_status.dart';

class LanternServiceLinux {
  LanternServiceLinux(this._rpc,
      {required this.socketPath, required this.token});

  final UnixSocketClient _rpc;
  final String socketPath;
  final String token;

  UnixSocketClient? _status;
  UnixSocketClient? _logs;

  Future<void> init() async {
    await _rpc.connect().timeout(const Duration(seconds: 5));
    _status = UnixSocketClient(socketPath: socketPath, token: token);
    _logs = UnixSocketClient(socketPath: socketPath, token: token);
  }

  Future<void> dispose() async {
    await _status?.close();
    await _logs?.close();
    await _rpc.close();
  }

  Future<Either<Failure, String>> connect() async {
    try {
      await _rpc.call('start_tunnel');
      return right('ok');
    } catch (e, st) {
      appLogger.error('[LS] connect() failed', e, st);
      return left(e.toFailure());
    }
  }

  Future<Either<Failure, String>> disconnect() async {
    try {
      await _rpc.call('stop_tunnel');
      return right('ok');
    } catch (e) {
      return left(e.toFailure());
    }
  }

  Future<Either<Failure, bool>> isVPNConnected() async {
    try {
      final res = await _rpc.call('is_vpn_running');
      final running = (res['result']?['running'] as bool?) ?? false;
      return right(running);
    } catch (e) {
      return left(e.toFailure());
    }
  }

  Stream<LanternStatus> watchVPNStatus() {
    return _status!.watch('watch_status').map((evt) {
      final raw = (evt['state'] as String?) ?? 'Disconnected';
      final err = evt['error'];
      return LanternStatus.fromJson(
          {'status': raw.toLowerCase(), 'error': err});
    });
  }

  Stream<List<String>> watchLogs() {
    return _logs!.watch('watch_logs').map((evt) {
      final lines = (evt['lines'] as List?)?.cast<String>() ?? const <String>[];
      return lines;
    });
  }
}
