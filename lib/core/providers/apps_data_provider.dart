import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';

final appsDataProvider =
    StateNotifierProvider<AppsNotifier, List<AppData>>((ref) {
  return AppsNotifier(ref);
});

class AppsNotifier extends StateNotifier<List<AppData>> {
  AppsNotifier(this.ref) : super([]) {
    _listenToApps();
  }

  final Ref ref;

  void _listenToApps() async {
    final ffiClient = await ref.watch(ffiClientProvider.future);
    await for (final appData in ffiClient.appsDataStream()) {
      state = [...state, appData];
    }
  }
}
