import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/injection_container.dart';

part 'server_location_notifier.g.dart';

@Riverpod()
class ServerLocationNotifier extends _$ServerLocationNotifier {
  final _localStorage = sl<LocalStorageService>();

  @override
  ServerLocationEntity build() {
    // Initialize the notifier, possibly fetching the initial server location.
    state = _localStorage.getServerLocations();
    return state;
  }

  Future<void> updateServerLocation(ServerLocationEntity serverLocation) async {
    state = serverLocation;
    _localStorage.saveServerLocation(serverLocation);
  }
}
