import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_data_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<AppData>> appsData(Ref ref) async* {
  final ffiClient = ref.watch(lanternServiceProvider);
  await for (final apps in ffiClient.appsDataStream()) {
    yield apps;
  }
}

// final appsDataProvider =
//     StateNotifierProvider<AppsNotifier, List<AppData>>((ref) {
//   return AppsNotifier(ref);
// });

// class AppsNotifier extends StateNotifier<List<AppData>> {
//   AppsNotifier(this.ref) : super([]) {
//     _listenToApps();
//   }

//   final Ref ref;

//   void _listenToApps() async {
//     final ffiClient = ref.watch(lanternServiceProvider);
//     await for (final apps in ffiClient.appsDataStream()) {
//       state = [...state, ...apps];
//     }
//   }
// }
