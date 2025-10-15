import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_data_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<AppData>> appsData(Ref ref) async* {
  final lanternService = ref.watch(lanternServiceProvider);
  await for (final apps in lanternService.appsDataStream()) {
    yield apps;
  }
}
