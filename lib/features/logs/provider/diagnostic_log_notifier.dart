import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostic_log_notifier.g.dart';

@Riverpod()
class DiagnosticLogNotifier extends _$DiagnosticLogNotifier {
  @override
  Stream<List<String>> build() {
    return ref.read(lanternServiceProvider).watchLogs("");
  }

  Future<List<String>> diagnosticLogFilePath() async {
    final coreService = ref.read(lanternServiceProvider);
    final result = await coreService.diagnosticLogFiles();
    return result.match(
      (failure) {
        appLogger.error(
          "Error fetching diagnostic log files: ${failure.error}",
        );
        return const <String>[];
      },
      (paths) => paths,
    );
  }
}
