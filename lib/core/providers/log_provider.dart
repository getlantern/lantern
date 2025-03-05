import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';

final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
  final logs = <String>[];
  final ffiClient = ref.watch(ffiClientProvider);
  await for (final log in ffiClient.logStream()) {
    logs.add(log);
    yield List.unmodifiable(logs);
  }
});


// final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
//   final ffiClient = ref.watch(ffiClientProvider);
//   yield await ffiClient.logStream().asBroadcastStream().toList();
// });