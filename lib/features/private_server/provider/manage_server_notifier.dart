import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_server_notifier.g.dart';

@Riverpod(keepAlive: true)
class ManageServerNotifier extends _$ManageServerNotifier {
  @override
  Future<List<PrivateServer>> build() async {
    final res = await ref.read(lanternServiceProvider).getPrivateServers();
    return res.fold((f) => <PrivateServer>[], (list) => list);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(lanternServiceProvider).getPrivateServers();
      return res.fold((_) => <PrivateServer>[], (l) => l);
    });
  }

  Future<void> deleteServer(String serverName) async {
    final res = await ref
        .read(lanternServiceProvider)
        .deletePrivateServerByName(serverName);
    await res.fold(
      (_) async {},
      (_) async => refresh(),
    );
  }

  Future<void> renameServer(String oldName, String newName) async {
    final res = await ref
        .read(lanternServiceProvider)
        .updatePrivateServerName(oldName, newName);
    await res.fold(
      (_) async {},
      (_) async => refresh(),
    );
  }
}
