import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/windows/pipe_client.dart';
import 'package:lantern/core/windows/pipe_commands.dart';

class LanternServiceWindows {
  LanternServiceWindows(this._rpcPipe);

  final PipeClient _rpcPipe;
  // dedicated streaming pipe
  PipeClient? _statusPipe;
  final _statusCtrl = StreamController<LanternStatus>.broadcast();

  Future<void> init() async {
    await _rpcPipe.connect();
    // start status streaming
    _statusPipe = PipeClient(token: _rpcPipe.token);
    await _statusPipe!.connect();

    final stream = await _statusPipe!.watchStatus();
    stream.listen((evt) {
      final state = (evt['state'] as String? ??
              (evt['data'] is Map ? (evt['data']['state'] as String?) : null) ??
              'disconnected')
          .toLowerCase();
      _statusCtrl.add(LanternStatus.fromJson({'status': state}));
    }, onError: (_) {});
  }

  Future<void> dispose() async {
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
}
