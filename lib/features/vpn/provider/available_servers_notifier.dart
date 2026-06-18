import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
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
    appLogger.debug('Forcing fetch of available servers...');
    final result = await fetchAvailableServers();
    result.fold(
      (failure) {
        appLogger.error('Error getting available servers: ${failure.error}');
      },
      (servers) {
        appLogger.debug(
          'Successfully fetched available servers, updating state...',
        );

        final merged = _mergeProbeHistory(servers, state.asData?.value);
        state = AsyncValue.data(merged);
        _pushFastestToSmartLocation(merged);
      },
    );
  }

  /// Carries last-known delays forward into [fresh] so servers don't flash
  /// "unavailable" after a config reload (which returns delay 0 until the next
  /// url-test). Allocates only when a carry-forward actually happens.
  AvailableServers _mergeProbeHistory(
    AvailableServers fresh,
    AvailableServers? previous,
  ) {
    if (previous == null) return fresh;
    if (!fresh.servers.any((s) => !s.hasSuccessfulProbe)) return fresh;

    final priorByTag = <String, SelectionHistory>{};
    for (final s in previous.servers) {
      if (s.hasSuccessfulProbe) priorByTag[s.tag] = s.selectionHistory!;
    }
    if (priorByTag.isEmpty) return fresh;

    List<Server>? merged;
    for (var i = 0; i < fresh.servers.length; i++) {
      final server = fresh.servers[i];
      if (server.hasSuccessfulProbe) continue; // fresh data is authoritative
      final prior = priorByTag[server.tag];
      if (prior == null) continue;
      merged ??= List<Server>.of(fresh.servers);
      merged[i] = server.copyWith(selectionHistory: prior);
    }
    return merged == null ? fresh : AvailableServers(merged);
  }

  /// Patches the delays of the servers in [results] (tag -> delay ms) in place
  /// instead of re-fetching the whole list, then re-pushes the fastest server
  /// to Smart Location. Servers absent from [results] are left untouched.
  void updateServerDelays(Map<String, int> results) {
    final current = state.asData?.value;
    if (current == null || results.isEmpty) return;

    appLogger.debug(
      'Updating server delays with new URL-test results: $results',
    );
    var changed = false;
    final updated = current.servers.map((server) {
      final delay = results[server.tag];
      if (delay == null) return server;
      changed = true;
      final history = (server.selectionHistory ?? SelectionHistory()).copyWith(
        lastSuccessDelayMs: delay,
      );
      return server.copyWith(selectionHistory: history);
    }).toList();

    if (!changed) return;

    appLogger.debug('Applying ${results.length} URL-test delays in place...');
    final servers = AvailableServers(updated);
    state = AsyncValue.data(servers);
    _pushFastestToSmartLocation(servers);
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
