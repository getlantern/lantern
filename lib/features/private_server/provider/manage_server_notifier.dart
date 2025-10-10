import 'package:lantern/core/common/app_eum.dart' show ServerLocationType;
import 'package:lantern/core/models/entity/private_server_entity.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/injection_container.dart';
import '../../../core/services/local_storage.dart';

part 'manage_server_notifier.g.dart';

@Riverpod(keepAlive: true)
class ManageServerNotifier extends _$ManageServerNotifier {
  @override
  List<PrivateServerEntity> build() {
    return sl<LocalStorageService>().getPrivateServer();
  }

  Future<void> deleteServer(String serverName) async {
    await sl<LocalStorageService>().deletePrivateServer(serverName);
    state = sl<LocalStorageService>().getPrivateServer();
    if (state.isEmpty) {

      final initalServer = ServerLocationEntity(
        autoSelect: true,
        serverLocation: 'Fastest Country',
        serverName: '',
        serverType: ServerLocationType.auto.name,
      );
      ref
          .read(serverLocationNotifierProvider.notifier)
          .updateServerLocation(initalServer);
    }
  }
}
