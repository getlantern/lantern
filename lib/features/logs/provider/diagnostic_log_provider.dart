import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostic_log_provider.g.dart';

@riverpod
Stream<List<String>> diagnosticLogStream(Ref ref) async* {
  final coreService = ref.watch(lanternServiceProvider);
  // Emit an initial empty snapshot so the logs screen renders immediately
  // instead of remaining in AsyncLoading until native emits a first batch.
  yield const <String>[];
  final path = await AppStorageUtils.getAppLogDirectory();
  yield* coreService.watchLogs(path);
}
