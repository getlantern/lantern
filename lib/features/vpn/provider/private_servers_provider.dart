import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/private_server.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'private_servers_provider.g.dart';

@Riverpod(keepAlive: true)
class PrivateServers extends _$PrivateServers {
  Future<List<PrivateServer>> _fetch() async {
    final core = ref.read(lanternServiceProvider);
    final res = await core.getPrivateServers();

    return res.fold(
      (f) => throw Exception(f.localizedErrorMessage),
      (v) => v,
    );
  }

  @override
  Future<List<PrivateServer>> build() async {
    return _fetch();
  }

  Future<void> refreshFromGo() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
