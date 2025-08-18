import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/windows/pipe_client.dart';
import 'package:lantern/core/windows/pipe_commands.dart';

class LanternServiceWindows {
  LanternServiceWindows(this._pipe);

  final PipeClient _pipe;
  final _statusCtrl = StreamController<LanternStatus>.broadcast();
  Timer? _pollTimer;

  Future<void> init() async {
    await _pipe.connect();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await _pipe.call(ServiceCommand.status.wire);
        final s = (res['state'] as String?) ?? 'disconnected';
        _statusCtrl.add(LanternStatus.fromJson({'status': s}));
      } catch (_) {}
    });
  }

  Future<void> dispose() async {
    _pollTimer?.cancel();
    await _pipe.close();
    await _statusCtrl.close();
  }

  Future<Either<Failure, String>> connect() async {
    try {
      await _pipe.call(ServiceCommand.setupAdapter.wire);
      await _pipe.call(ServiceCommand.startTunnel.wire);
      return right('ok');
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, String>> disconnect() async {
    try {
      await _pipe.call(ServiceCommand.stopTunnel.wire);
      return right('ok');
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    try {
      await _pipe.call(ServiceCommand.connectToServer.wire, {
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
      final res = await _pipe.call(ServiceCommand.isVPNRunning.wire);
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
