import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
  final logs = <String>[];
  final ffiClient = ref.watch(lanternServiceProvider);
  await for (final log in ffiClient.logStream()) {
    logs.add(log);
    yield List.unmodifiable(logs);
  }
});
