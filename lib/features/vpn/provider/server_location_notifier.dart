import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/utils/country_utils.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/available_servers.dart';
import '../../../core/services/injection_container.dart';

part 'server_location_notifier.g.dart';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  final _localStorage = sl<LocalStorageService>();

  @override
  ServerLocationEntity build() {
    // Initialize the notifier, possibly fetching the initial server location.
    state = _localStorage.getSavedServerLocations();
    return state;
  }

  ///Updates the server location in the state and saves it to local storage.
  ///notify UI about changes
  Future<void> updateServerLocation(ServerLocationEntity serverLocation) async {
    state = serverLocation;
    _localStorage.saveServerLocation(serverLocation);
  }

  Future<void> ifNeededGetAutoServerLocation() async {
    final status = ref.read(vpnProvider);
    if (status == VPNStatus.connected &&
        state.serverType.toServerLocationType == ServerLocationType.auto) {
      appLogger.debug(
          "Current server location is 'auto'. Fetching auto server location.");
      final result = await getAutoServerLocation();
      result.fold(
        (error) {
          // Handle error case, possibly logging or showing a message.
          appLogger.error("Failed to fetch auto server location: $error");
        },
        (autoLocation) {
          final countryName = autoLocation.location!.country;
          final cityName = autoLocation.location!.city;
          final autoServer = ServerLocationEntity(
            serverType: ServerLocationType.auto.name,
            serverName: '',
            autoSelect: true,
            displayName: '',
            city: autoLocation.location!.city,
            autoLocationParam: AutoLocationEntity(
              countryCode: autoLocation.location!.countryCode,
              country: countryName,
              displayName: '$countryName - $cityName',
              tag: autoLocation.tag
            ),
          );

          updateServerLocation(autoServer);
          appLogger.debug(
              "Fetched auto server location: ${autoLocation.location?.toJson()}");
        },
      );
    } else {
      appLogger.debug(
          "Current server location is not 'auto' or connected . No need to fetch auto server location.");
    }
  }

  Future<Either<Failure, Server>> getAutoServerLocation() async {
    final result =
        await ref.read(lanternServiceProvider).getAutoServerLocation();
    return result;
  }
}
