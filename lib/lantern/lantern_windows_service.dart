import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/windows/pipe_client.dart';
import 'package:lantern/core/windows/pipe_commands.dart';

class LanternServiceWindows {
  LanternServiceWindows(this._rpcPipe);

  final PipeClient _rpcPipe;
  // dedicated streaming pipes
  PipeClient? _statusPipe;
  PipeClient? _logsPipe;

  StreamSubscription<Map<String, dynamic>>? _statusSub;
  final _statusCtrl = StreamController<LanternStatus>.broadcast();

  Future<void> init() async {
    try {
      appLogger.info('[WS] RPC connect()…');
      await _rpcPipe.connect().timeout(const Duration(seconds: 5));
      appLogger.info('[WS] RPC connected. token=${_rpcPipe.token}');
    } catch (e, st) {
      appLogger.error('[WS] RPC connect() failed', e, st);
      rethrow;
    }
    try {
      _statusPipe = PipeClient(token: _rpcPipe.token);
      final stream = _statusPipe!.watchStatus();
      appLogger.info('[WS] watchStatus() stream created');

      _statusSub = stream.listen((evt) {
        final raw = (evt['state'] as String?) ?? 'Disconnected';
        final state = raw.toLowerCase();
        _statusCtrl.add(LanternStatus.fromJson({'status': state}));
      }, onError: (err, st) {
        appLogger.error('[WS] Status stream error', err, st);
      }, onDone: () {
        appLogger.info('[WS] Status stream completed');
      });
    } catch (e, st) {
      appLogger.error('[WS] watchStatus() setup failed', e, st);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _statusPipe?.close();
    await _rpcPipe.close();
    await _statusCtrl.close();
  }

  Future<Either<Failure, String>> connect() async {
    try {
      await _rpcPipe.call(ServiceCommand.startTunnel.wire);
      return right('ok');
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, String>> disconnect() async {
    try {
      await _rpcPipe.call(ServiceCommand.stopTunnel.wire);
      return right('ok');
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    try {
      await _rpcPipe.call(ServiceCommand.connectToServer.wire, {
        'location': location,
        'tag': tag,
      });
      return right('ok');
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      final res = await _rpcPipe.call(ServiceCommand.isVPNRunning.wire);
      final running = (res['running'] as bool?) ?? false;
      _statusCtrl.add(LanternStatus.fromJson(
          {'status': running ? 'Connected' : 'Disconnected'}));
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Stream<LanternStatus> watchVPNStatus() => _statusCtrl.stream;

  Stream<List<String>> watchLogs() {
    _logsPipe ??= PipeClient(token: _rpcPipe.token);
    return _logsPipe!.watchLogs();
  }
}
