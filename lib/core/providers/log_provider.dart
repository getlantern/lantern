import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

final diagnosticLogProvider = StreamProvider<List<String>>((ref) async* {
  final ffiClient = ref.watch(lanternServiceProvider);
  yield* ffiClient.logsStream();
});
