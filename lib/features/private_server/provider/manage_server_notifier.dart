import 'package:lantern/core/models/private_server_entity.dart';
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

  void deleteServer(String serverName) {
    sl<LocalStorageService>().deletePrivateServer(serverName);
    state = sl<LocalStorageService>().getPrivateServer();
  }

}
