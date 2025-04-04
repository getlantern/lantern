import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/utils/log_utils.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'diagnostic_log_provider.g.dart';

@riverpod
Stream<List<String>> diagnosticLogStream(Ref ref) async* {
  final coreService = ref.watch(lanternServiceProvider);
  final path = await LogUtils.getAppLogDirectory();
  yield* coreService.watchLogs(path);
}
