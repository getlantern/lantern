import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_data_provider.g.dart';

@Riverpod(keepAlive: true)
class AppsData extends _$AppsData {
  @override
  FutureOr<List<AppData>> build() async {
    final ffiClient = await ref.watch(ffiClientProvider.future);
    final apps = <AppData>[];

    // Listen to the stream and add to state
    ffiClient.appsDataStream().listen((appData) {
      apps.add(appData);
      state = AsyncData([...apps]);
    });

    return apps;
  }
}
