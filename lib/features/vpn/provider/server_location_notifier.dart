import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart' show sl;
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_location_notifier.g.dart';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  LocalStorageService get _storage => sl<LocalStorageService>();

  @override
  ServerLocation build() {
    return _storage.getServerLocation() ?? _defaultLocation();
  }

  Future<void> updateServerLocation(ServerLocation entity) async {
    final current = state;
    if (entity.serverType != ServerLocationType.auto.name) {
      //Preserve auto location metadata when switching to a non-auto server,
      // so we can show user smart location
      final updated = entity.copyWith(autoLocation: current.autoLocation);
      state = updated;
      await _storage.saveServerLocation(updated);
    } else {
      state = entity;
      await _storage.saveServerLocation(entity);
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

  Future<void> ifNeededGetAutoServerLocation() async {
    final status = ref.read(vpnProvider);
    final current = state;

    if (status == VPNStatus.connected &&
        current.serverType.toServerLocationType == ServerLocationType.auto) {
      final result = await ref
          .read(lanternServiceProvider)
          .getAutoServerLocation();
      await result.fold(
        (error) async {
          appLogger.error("Failed to fetch auto server location: $error");
        },
        (autoLocation) async {
          final countryName = autoLocation.location!.country;
          final cityName = autoLocation.location!.city;

          await updateServerLocation(
            ServerLocation(
              serverType: ServerLocationType.auto.name,
              serverName: '',
              displayName: '',
              protocol: '',
              city: cityName,
              autoLocation: AutoLocation(
                countryCode: autoLocation.location!.countryCode,
                country: countryName,
                displayName: '$countryName - $cityName',
                tag: autoLocation.tag,
              ),
            ),
          );
        },
      );
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
