import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/split_tunneling/app_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_data_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<AppData>> appsData(Ref ref) async* {
  final ffiClient = await ref.watch(ffiClientProvider.future);
  final apps = <AppData>[];

  yield [];

  await for (final appData in ffiClient.appsDataStream()) {
    apps.add(appData);
    yield [...apps];
  }
}
