import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  /// Fetches the list of Lantern servers for the user
  Future<void> getLanternServers() async {
    // Fetch the list of Lantern servers for the given location.
    final result =
        await ref.read(lanternServiceProvider).getLanternAvailableServers();

    result.fold(
      (error) {
        // Handle error case, possibly logging or showing a message.
        dbLogger.error("Failed to fetch Lantern servers: $error");
      },
      (servers) {
        appLogger.debug(
            "Fetched Lantern servers for location", servers.toJson());
      },
    );
  }

  Future<Either<Failure, String>> getAutoServerLocation() async {
    final result =
        await ref.read(lanternServiceProvider).getAutoServerLocation();

    return result;
  }
}
