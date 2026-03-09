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
  Future<ServerLocation> build() async {
    return _storage.getServerLocation() ?? _defaultLocation();
  }

  Future<void> updateServerLocation(ServerLocation entity) async {
    final current = state.value;
    if (entity.serverType != ServerLocationType.auto.name) {
      //Preserve auto location metadata when switching to a non-auto server,
      // so we can show user smart location
      final updated = entity.copyWith(autoLocation: current?.autoLocation);
      state = AsyncData(updated);
      await _storage.saveServerLocation(updated);
    } else {
      state = AsyncData(entity);
      await _storage.saveServerLocation(entity);
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
