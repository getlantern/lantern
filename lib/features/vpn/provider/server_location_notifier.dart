import 'dart:async';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_location_notifier.g.dart';

@Riverpod(keepAlive: true)
class ServerLocationNotifier extends _$ServerLocationNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  @override
  ServerLocation build() {
    // Every change to the selected/resolved location is mirrored into the
    // native widget so it can show where the tunnel exits.
    listenSelf((_, next) => _publishToWidget(next));
    final cached = _storage.getServerLocation();
    final initial = cached ?? _defaultLocation();
    appLogger.debug(
      'ServerLocationNotifier.build() cached=${cached != null} '
      'type=${initial.serverType} city=${initial.city}',
    );
    // Use cached value for instant display, then refresh from radiance.
    fetchServerLocation();
    return initial;
  }

  /// Fetches the current server location from radiance.
  /// If the VPN isn't connected, uses the cached value.
  /// If auto-selected, fetches the auto location; otherwise fetches the
  /// explicitly selected server.
  Future<void> fetchServerLocation() async {
    final status = ref.read(vpnProvider);
    if (status != VPNStatus.connected) {
      appLogger.debug(
        'fetchServerLocation: VPN not connected ($status), using cached value',
      );
      return;
    }

    final cached = _storage.getServerLocation();
    final isAuto =
        cached == null ||
        cached.serverType.toServerLocationType == ServerLocationType.auto;

    appLogger.debug('fetchServerLocation: VPN connected, isAuto=$isAuto');

    if (isAuto) {
      await _fetchAutoLocation();
    } else {
      await _fetchSelectedLocation();
    }
  }

  Future<void> _fetchAutoLocation() async {
    appLogger.debug('Fetching auto server location from radiance...');
    final result = await ref
        .read(lanternServiceProvider)
        .getAutoServerLocation();
    if (!ref.mounted) return;
    result.fold(
      (error) {
        // Expected when VPN isn't connected yet — auto location is only
        // available after the tunnel starts. The cached value (from the
        // last session) is used until the server-location event arrives.
        appLogger.debug('Auto server location not available yet: $error');
      },
      (autoServer) {
        final countryName = autoServer.location.country;
        final cityName = autoServer.location.city;
        final location = ServerLocation(
          serverType: ServerLocationType.auto.name,
          serverName: '',
          displayName: '',
          protocol: '',
          city: cityName,
          autoLocation: AutoLocation(
            countryCode: autoServer.location.countryCode,
            country: countryName,
            displayName: '$countryName - $cityName',
            tag: autoServer.tag,
          ),
        );
        appLogger.debug('Fetched auto server location: ${location.toJson()}');
        state = location;
        _storage.saveServerLocation(location);
      },
    );
  }

  Future<void> _fetchSelectedLocation() async {
    appLogger.debug('Fetching selected server location from radiance...');
    final result = await ref
        .read(lanternServiceProvider)
        .getSelectedServerLocation();
    if (!ref.mounted) return;
    result.fold(
      (error) {
        appLogger.error(
          'Failed to fetch selected server from radiance: $error',
          error,
        );
      },
      (location) {
        appLogger.debug(
          'Fetched selected server location: ${location.toJson()}',
        );
        state = location;
        _storage.saveServerLocation(location);
      },
    );
  }

  void updateServerLocation(ServerLocation entity) {
    final current = state;
    final ServerLocation updated;
    if (entity.serverType != ServerLocationType.auto.name) {
      //Preserve auto location metadata when switching to a non-auto server,
      // so we can show user smart location
      updated = entity.copyWith(autoLocation: current.autoLocation);
    } else {
      updated = entity;
    }
    appLogger.debug(
      'updateServerLocation: type=${updated.serverType} '
      'name=${updated.serverName} city=${updated.city}',
    );
    state = updated;
    _storage.saveServerLocation(updated);
  }

  Future<void> refreshAutoLocationIfNeeded() async {
    final status = ref.read(vpnProvider);
    final current = state;
    final isAuto =
        current.serverType.toServerLocationType == ServerLocationType.auto;

    appLogger.debug('refreshAutoLocationIfNeeded: vpn=$status isAuto=$isAuto');

    if (status == VPNStatus.connected && isAuto) {
      await _fetchAutoLocation();
    }
  }

  /// Flips the active selection to auto and clears any stale custom-server
  /// identity fields so downstream UI does not keep highlighting a previous
  /// manual selection. The existing [autoLocation] metadata is preserved so
  /// the Smart Location label remains available until the next push event.
  Future<void> switchToAuto() async {
    if (state.serverType == ServerLocationType.auto.name) return;
    final updated = state.copyWith(serverType: ServerLocationType.auto.name);
    state = updated;
    await _storage.saveServerLocation(updated);
  }

  void _publishToWidget(ServerLocation location) {
    final isAuto =
        location.serverType.toServerLocationType == ServerLocationType.auto;
    final auto = location.autoLocation;
    unawaited(
      ref
          .read(lanternServiceProvider)
          .updateWidgetLocation(
            city: location.city,
            country: isAuto ? (auto?.country ?? '') : location.country,
            countryCode: isAuto
                ? (auto?.countryCode ?? '')
                : location.countryCode,
            displayName: isAuto
                ? (auto?.displayName ?? '')
                : location.displayName,
          ),
    );
  }

  static ServerLocation _defaultLocation() => ServerLocation(
    serverType: ServerLocationType.auto.name,
    serverName: '',
    displayName: '',
    protocol: '',
    city: '',
  );
}
