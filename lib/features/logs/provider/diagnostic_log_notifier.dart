import 'dart:async';

import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostic_log_notifier.g.dart';

@Riverpod()
class DiagnosticLogNotifier extends _$DiagnosticLogNotifier {
  @override
  Stream<List<String>> build() {
    final radianceBatches = ref.read(lanternServiceProvider).watchLogs("");
    final flutterBatches = flutterLogLinesStream.map((line) => [line]);
    return accumulateLogBatches(
      _mergeStreams([radianceBatches, flutterBatches]),
    );
  }

  Future<List<String>> diagnosticLogFilePath() async {
    final coreService = ref.read(lanternServiceProvider);
    final result = await coreService.diagnosticLogFiles();
    return result.match((failure) {
      appLogger.error("Error fetching diagnostic log files: ${failure.error}");
      return const <String>[];
    }, (paths) => paths);
  }
}

Stream<T> _mergeStreams<T>(List<Stream<T>> streams) {
  final controller = StreamController<T>();
  final subs = <StreamSubscription<T>>[];
  controller.onListen = () {
    for (final s in streams) {
      subs.add(s.listen(
        controller.add,
        onError: controller.addError,
      ));
    }
  };
  controller.onCancel = () async {
    for (final sub in subs) {
      await sub.cancel();
    }
    subs.clear();
  };
  return controller.stream;
}
