import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

part 'app_list_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<AppData>> appList(Ref ref) {
  final service = sl<LanternCoreService>();
  return service.appsDataStream();
}
