import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostic_log_provider.g.dart';

@riverpod
Stream<List<String>> diagnosticLogStream(Ref ref) async* {
  final coreService = ref.watch(lanternServiceProvider);
  // Emit once so the logs screen doesn't stay in loading.
  yield const <String>[];
  final path = await AppStorageUtils.getAppLogDirectory();
  yield* coreService.watchLogs(path);
}
