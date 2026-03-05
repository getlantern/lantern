import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_location_notifier.g.dart';

const selectedServerLocationPrefsKey = 'selected_server_location';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  final _storage = LocalStorageService();

  @override
  Future<ServerLocation> build() async {
    final raw = await _storage.getString(selectedServerLocationPrefsKey);
    if (raw == null || raw.isEmpty) return _defaultLocation();
    try {
      return ServerLocation.fromJsonString(raw);
    } catch (e, st) {
      appLogger.error('Failed to parse server location from prefs', e, st);
      return _defaultLocation();
    }
  }

  Future<void> updateServerLocation(ServerLocation entity) async {
    final current = state.value;
    if (entity.serverType != ServerLocationType.auto.name) {
      ///Preserve auto location metadata when switching to a non-auto server, so we can show user smart location
      final updated = entity.copyWith(autoLocation: current?.autoLocation);
      state = AsyncData(updated);
      await _storage.setString(
          selectedServerLocationPrefsKey, updated.toJsonString());
    } else {
      state = AsyncData(entity);
      await _storage.setString(
          selectedServerLocationPrefsKey, entity.toJsonString());
    }
  }

  Future<void> ifNeededGetAutoServerLocation() async {
    final status = ref.read(vpnProvider);
    final current = state.value;

    if (status == VPNStatus.connected &&
        current != null &&
        current.serverType.toServerLocationType == ServerLocationType.auto) {
      final result =
          await ref.read(lanternServiceProvider).getAutoServerLocation();
      result.fold(
        (error) =>
            appLogger.error("Failed to fetch auto server location: $error"),
        (autoLocation) {
          final countryName = autoLocation.location!.country;
          final cityName = autoLocation.location!.city;

          updateServerLocation(ServerLocation(
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
          ));
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
