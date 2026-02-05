import 'package:lantern/core/models/server_location.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

part 'server_location_notifier.g.dart';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  @override
  Future<ServerLocation> build() async {
    final res =
        await ref.read(lanternServiceProvider).getSelectedServerLocation();
    return res.match(
      (f) {
        appLogger.error('Failed to load selected server location: ${f.error}');
        return ServerLocation(
          serverType: ServerLocationType.auto.name,
          serverName: '',
          displayName: '',
          protocol: '',
          city: '',
        );
      },
      (loc) => loc,
    );
  }

  Future<void> updateServerLocation(ServerLocation entity) async {
    // Update UI immediately; if persisting fails we re-load from core
    state = AsyncData(entity);

    final res =
        await ref.read(lanternServiceProvider).setSelectedServerLocation(
              entity,
            );

    res.fold(
      (f) async {
        appLogger.error('Failed to persist server location: ${f.error}');
        // Snap back to whatever core thinks is selected
        state = AsyncData(await build());
      },
      (_) {},
    );
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

          final autoServer = ServerLocation(
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
          );

          updateServerLocation(autoServer);
        },
      );
    }
  }
}
