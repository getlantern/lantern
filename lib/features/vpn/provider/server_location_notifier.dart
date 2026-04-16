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
    // Use cached value for instant display, then refresh from radiance.
    fetchServerLocation();
    return _storage.getServerLocation() ?? _defaultLocation();
  }

  /// Fetches the current server location from radiance.
  /// If the cached location is auto-selected, fetches the auto location
  /// (available when VPN is already connected); falls back to cached value
  /// silently if the VPN isn't connected yet.
  /// For explicitly selected servers, fetches from radiance immediately.
  Future<void> fetchServerLocation() async {
    final cached = _storage.getServerLocation();
    final isAuto =
        cached == null ||
        cached.serverType.toServerLocationType == ServerLocationType.auto;

    if (isAuto) {
      await _fetchAutoLocation();
    } else {
      await _fetchSelectedLocation();
    }
  }

  Future<void> _fetchAutoLocation() async {
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
        appLogger.debug(
          'Fetched auto server location from radiance: ${location.toJson()}',
        );
        state = location;
        _storage.saveServerLocation(location);
      },
    );
  }

  Future<void> _fetchSelectedLocation() async {
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
          'Fetched selected server location from radiance: ${location.toJson()}',
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
    state = updated;
    _storage.saveServerLocation(updated);
  }

  Future<void> refreshAutoLocationIfNeeded() async {
    final status = ref.read(vpnProvider);
    final current = state;

    if (status == VPNStatus.connected &&
        current.serverType.toServerLocationType == ServerLocationType.auto) {
      await _fetchAutoLocation();
    }
  }

  static ServerLocation _defaultLocation() => ServerLocation(
    serverType: ServerLocationType.auto.name,
    serverName: '',
    displayName: '',
    protocol: '',
    city: '',
  );
}
