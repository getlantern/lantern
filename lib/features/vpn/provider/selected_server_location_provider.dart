// lib/features/vpn/provider/selected_server_location_provider.dart
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_server_location_provider.g.dart';

@Riverpod(keepAlive: true)
class SelectedServerLocation extends _$SelectedServerLocation {
  @override
  Future<ServerLocation> build() async {
    final res =
        await ref.read(lanternServiceProvider).getSelectedServerLocation();

    return res.fold(
      (f) => throw Exception(f.localizedErrorMessage),
      (v) => v,
    );
  }

  Future<void> refreshFromGo() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
