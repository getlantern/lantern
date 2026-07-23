import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'available_servers_notifier.g.dart';

const _availableServersSettleReloadThrottle = Duration(seconds: 30);
const _availableServersSettleReloadDelay = Duration(seconds: 4);

@Riverpod(keepAlive: true)
class AvailableServersNotifier extends _$AvailableServersNotifier {
  DateTime? _lastSettleReloadAt;
  Future<void>? _settleReload;

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
    // The fetch is async and this notifier can be disposed while it is in
    // flight (e.g. the app tears down during an integration test). Writing
    // state on a disposed Ref throws, so bail out if we are no longer mounted.
    if (!ref.mounted) {
      return;
    }
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

  /// Reloads available servers from the latest persisted Smart Location probe data.
  Future<void> refreshAvailableServersAfterProbeSettle() async {
    final now = DateTime.now();
    final lastReload = _lastSettleReloadAt;
    await forceFetchAvailableServers();

    if (_settleReload != null) {
      await _settleReload;
      return;
    }
    if (lastReload != null &&
        now.difference(lastReload) < _availableServersSettleReloadThrottle) {
      return;
    }
    _lastSettleReloadAt = now;

    final settleReload = Future<void>(() async {
      await Future.delayed(_availableServersSettleReloadDelay);
      await forceFetchAvailableServers();
    });
    _settleReload = settleReload;
    try {
      await settleReload;
    } finally {
      if (_settleReload == settleReload) {
        _settleReload = null;
      }
    }
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
