import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_server_notifier.g.dart';

@Riverpod(keepAlive: true)
class ManageServerNotifier extends _$ManageServerNotifier {
  @override
  void build() async {}

  Future<void> refresh() async {
    final res = await ref
        .read(availableServersProvider.notifier)
        .forceFetchAvailableServers();
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
