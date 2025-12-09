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
      appLogger.info('[WS] watchStatus() stream created');
    } catch (e, st) {
      appLogger.error('[WS] watchStatus() setup failed', e, st);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _statusPipe?.close();
    await _rpcPipe.close();
  }

  Future<Either<Failure, String>> connect() async {
    try {
      await _rpcPipe.call(ServiceCommand.startTunnel.wire);
      return right('ok');
    } catch (e) {
      appLogger.error('[WS] connect() failed', e);
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
      appLogger.error(
          '[WS] connectToServer() failed for location=$location, tag=$tag', e);
      return Left(e.toFailure());
    }
  }

  Future<Either<Failure, bool>> isVPNConnected() async {
    try {
      final res = await _rpcPipe.call(ServiceCommand.isVPNRunning.wire);
      final running = (res['running'] as bool?) ?? false;
      return right(running);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  Stream<LanternStatus> watchVPNStatus() {
    _statusPipe ??= PipeClient(token: _rpcPipe.token);

    return _statusPipe!.watchStatus().map((evt) {
      final data = evt;
      final raw = data['state'] as String? ?? 'Disconnected';
      final error = data['error'];
      return LanternStatus.fromJson(
          {'status': raw.toLowerCase(), 'error': error});
    }).handleError((error, st) {
      appLogger.error('[WS] watchStatus() stream error', error, st);
    });
  }

  Stream<List<String>> watchLogs() {
    _logsPipe ??= PipeClient(token: _rpcPipe.token);
    return _logsPipe!.watchLogs();
  }
}
