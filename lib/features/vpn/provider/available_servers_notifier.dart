import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_servers_notifier.g.dart';

@Riverpod(keepAlive: true)
class AvailableServersNotifier extends _$AvailableServersNotifier {
  static const _maxRetries = 6;
  static const _initialDelay = Duration(milliseconds: 200);

  @override
  Future<AvailableServers> build() async {
    return _fetchWithRetry();
  }

  Future<void> updateServers() async {
    try {
      final servers = await _fetchWithRetry();
      appLogger.debug('Updated available servers: ${servers.toJson()}');
      state = AsyncValue.data(servers);
    } catch (e, st) {
      appLogger.error('Error updating available servers: $e', st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<AvailableServers> _fetchWithRetry() async {
    var delay = _initialDelay;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final result =
          await ref.read(lanternServiceProvider).getLanternAvailableServers();

      final serversOrFailure = result.fold(
        (failure) => failure,
        (servers) => servers,
      );

      if (serversOrFailure is AvailableServers) {
        appLogger.debug('Available servers: ${serversOrFailure.toJson()}');
        return serversOrFailure;
      }

      final failure = serversOrFailure as Failure;
      final msg = (failure.localizedErrorMessage).toLowerCase();

      final coreNotReady = msg.contains('not initialized') ||
          msg.contains('radiance') ||
          msg.contains('available servers');

      appLogger.warning(
        'Fetch servers attempt ${attempt + 1}/$_maxRetries failed: '
        '${failure.localizedErrorMessage}',
      );

      if (attempt == _maxRetries - 1 || !coreNotReady) {
        break;
      }

      await Future.delayed(delay);
      delay *= 2;
    }

    throw Exception('Could not load server list. Please try again.');
  }
}
