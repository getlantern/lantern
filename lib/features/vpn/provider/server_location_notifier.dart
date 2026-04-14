import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'server_location_notifier.g.dart';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  @override
  ServerLocation build() {
    // Start with default (auto), then fetch the actual selection from radiance.
    _fetchFromRadiance();
    return _defaultLocation();
  }

  Future<void> _fetchFromRadiance() async {
    final result = await ref
        .read(lanternServiceProvider)
        .getSelectedServerLocation();
    if (!ref.mounted) return;
    result.fold(
      (error) {
        appLogger.error('Failed to fetch selected server from radiance: $error');
      },
      (location) {
        state = location;
      },
    );
    // If VPN is connected with auto/smart location, fetch the actual
    // connected server details so the UI shows the real location instead
    // of just "Fastest Server".
    await ifNeededGetAutoServerLocation();
  }

  void updateServerLocation(ServerLocation entity) {
    final current = state;
    if (entity.serverType != ServerLocationType.auto.name) {
      //Preserve auto location metadata when switching to a non-auto server,
      // so we can show user smart location
      state = entity.copyWith(autoLocation: current.autoLocation);
    } else {
      state = entity;
    }
  }

  Future<void> ifNeededGetAutoServerLocation() async {
    final status = ref.read(vpnProvider);
    final current = state;

    if (status == VPNStatus.connected &&
        current.serverType.toServerLocationType == ServerLocationType.auto) {
      final result = await ref
          .read(lanternServiceProvider)
          .getAutoServerLocation();
      result.fold(
        (error) {
          appLogger.error("Failed to fetch auto server location: $error");
        },
        (autoLocation) {
          final countryName = autoLocation.location.country;
          final cityName = autoLocation.location.city;

          updateServerLocation(
            ServerLocation(
              serverType: ServerLocationType.auto.name,
              serverName: '',
              displayName: '',
              protocol: '',
              city: cityName,
              autoLocation: AutoLocation(
                countryCode: autoLocation.location.countryCode,
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
