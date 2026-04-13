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

  /// Updates only the auto-location metadata (the "Smart Location" label)
  /// without changing the user's active selection. Used by the `server-location`
  /// push event from the Go side, which reports what auto-routing chose and
  /// must NOT overwrite a custom server the user has selected.
  Future<void> updateAutoLocationMetadata(AutoLocation autoLocation) async {
    final updated = state.copyWith(autoLocation: autoLocation);
    state = updated;
    await _storage.saveServerLocation(updated);
  }

  /// Flips the active selection to auto without discarding any existing
  /// fields. The previous custom-server fields (serverName, country, etc.)
  /// stay in state — only [serverType] changes — so the existing
  /// autoLocation metadata (if any) remains and the Smart Location label
  /// doesn't briefly flicker to "fastest_server" before the next push event.
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
