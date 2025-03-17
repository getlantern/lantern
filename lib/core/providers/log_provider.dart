import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';

final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
  final logs = <String>[];
  final ffiClient = await ref.watch(ffiClientProvider.future);
  await for (final log in ffiClient.logStream()) {
    logs.add(log);
    yield List.unmodifiable(logs);
  }
});
