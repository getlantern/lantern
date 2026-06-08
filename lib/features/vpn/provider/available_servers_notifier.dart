import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_servers_notifier.g.dart';

const _serverReachabilityRefreshThrottle = Duration(seconds: 30);
const _urlTestAlreadyRunningRetryDelay = Duration(seconds: 4);
const _urlTestAlreadyRunningAttempts = 2;

@Riverpod(keepAlive: true)
class AvailableServersNotifier extends _$AvailableServersNotifier {
  DateTime? _lastReachabilityRefreshAt;

  @override
  Future<AvailableServers> build() async {
    final result = await fetchAvailableServers();
    return result.fold(
      (failure) {
        appLogger.error('Error getting available servers: ${failure.error}');
        throw Exception('Failed to load available servers');
      },
      (servers) {
        _pushFastestToSmartLocation(servers);
        return servers;
      },
    );
  }

  /// Fetches the available servers from the Lantern.
  Future<Either<Failure, AvailableServers>> fetchAvailableServers() async {
    appLogger.debug('Fetching available servers from Lantern...');
    return await ref.read(lanternServiceProvider).getLanternAvailableServers();
  }

  /// Forces a fetch of the available servers and updates the state.
  /// Updates UI accordingly.
  Future<void> forceFetchAvailableServers() async {
    final result = await fetchAvailableServers();
    result.fold(
      (failure) {
        appLogger.error('Error getting available servers: ${failure.error}');
      },
      (servers) {
        state = AsyncValue.data(servers);
        _pushFastestToSmartLocation(servers);
      },
    );
  }

  /// Refreshes Smart Location probe history before reloading the server list.
  Future<void> refreshServerReachability() async {
    final now = DateTime.now();
    final lastRefresh = _lastReachabilityRefreshAt;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < _serverReachabilityRefreshThrottle) {
      await forceFetchAvailableServers();
      return;
    }
    _lastReachabilityRefreshAt = now;

    for (var attempt = 0; attempt < _urlTestAlreadyRunningAttempts; attempt++) {
      final result = await ref.read(lanternServiceProvider).runURLTests();
      final shouldRetry = result.fold((failure) {
        if (_urlTestsAlreadyRunning(failure)) {
          appLogger.debug(
            'URL tests already running while opening server selection',
          );
          return true;
        }
        appLogger.debug(
          'Unable to refresh server URL tests before opening selection: '
          '${failure.error}',
        );
        return false;
      }, (_) => false);

      if (!shouldRetry) break;
      if (attempt == _urlTestAlreadyRunningAttempts - 1) break;

      await Future.delayed(_urlTestAlreadyRunningRetryDelay);
    }

    await forceFetchAvailableServers();
  }

  /// Pushes the fastest Lantern server to the Smart Location if the current selection is auto
  void _pushFastestToSmartLocation(AvailableServers servers) {
    final fastest = servers.fastestLanternServer;
    if (fastest == null) return;

    final current = ref.read(serverLocationProvider);
    if (current.serverType.toServerLocationType != ServerLocationType.auto) {
      return;
    }
    if (current.autoLocation?.tag == fastest.tag) return;

    final country = fastest.location.country;
    final city = fastest.location.city;
    appLogger.debug(
      'Pushing fastest server to Smart Location: '
      'tag=${fastest.tag} delay=${fastest.selectionHistory?.lastSuccessDelayMs}ms',
    );
    ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(
          ServerLocation(
            serverType: ServerLocationType.auto.name,
            serverName: '',
            displayName: '',
            protocol: '',
            city: city,
            autoLocation: AutoLocation(
              countryCode: fastest.location.countryCode,
              country: country,
              displayName: '$country - $city',
              tag: fastest.tag,
            ),
          ),
        );
  }
}

bool _urlTestsAlreadyRunning(Failure failure) {
  final error = failure.error.toLowerCase();
  return error.contains('offline tests already running') ||
      error.contains('url tests already running');
}
