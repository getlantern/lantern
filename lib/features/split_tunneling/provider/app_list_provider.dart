import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_list_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<List<AppData>> appList(Ref ref) {
  final service = sl<LanternCoreService>();
  return service.appsDataStream();
}
