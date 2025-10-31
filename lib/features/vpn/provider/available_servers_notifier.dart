import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_servers_notifier.g.dart';

@Riverpod(keepAlive: true)
class AvailableServersNotifier extends _$AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async {
    final result = await fetchAvailableServers();
    return result.fold(
      (failure) {
        appLogger.error(
            'Error getting available servers: ${failure.localizedErrorMessage}');
        throw Exception('Failed to available servers');
      },
      (servers) {
        appLogger.debug('Available servers: ${servers.toJson()}');
        return servers;
      },
    );
  }

  /// Fetches the available servers from the Lantern.
  Future<Either<Failure, AvailableServers>> fetchAvailableServers() async {
    return await ref.read(lanternServiceProvider).getLanternAvailableServers();
  }

  /// Forces a fetch of the available servers and updates the state.
  /// Updates UI accordingly.
  Future<void> forceFetchAvailableServers() async {
    final result = await fetchAvailableServers();
    result.fold(
      (failure) {
        appLogger.error(
            'Error getting available servers: ${failure.localizedErrorMessage}');
      },
      (servers) {
        appLogger.debug('Available servers: ${servers.toJson()}');
        state = AsyncValue.data(servers);
      },
    );
  }
}
