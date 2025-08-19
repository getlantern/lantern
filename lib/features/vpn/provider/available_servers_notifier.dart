import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_servers_notifier.g.dart';

@Riverpod(keepAlive: true)
class AvailableServersNotifier extends _$AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async {
    final result =
        await ref.read(lanternServiceProvider).getLanternAvailableServers();
    return result.fold(
      (failure) {
        appLogger.error(
            'Error getting available servers: ${failure.localizedErrorMessage}');
        throw Exception('Failed to get user data');
      },
      (servers) {
        appLogger.debug('Available servers: ${servers.toJson()}');
        return servers;
      },
    );
  }

  Future<void> updateServers() async {
    final result =
        await ref.read(lanternServiceProvider).getLanternAvailableServers();
    result.fold(
      (failure) {
        appLogger.error(
            'Error updating available servers: ${failure.localizedErrorMessage}');
      },
      (servers) {
        appLogger.debug('Updated available servers: $servers');
        state = AsyncValue.data(servers);
      },
    );
  }
}
