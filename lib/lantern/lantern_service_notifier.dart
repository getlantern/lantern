import 'package:lantern/lantern/lantern_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/services/injection_container.dart';

part 'lantern_service_notifier.g.dart';

@Riverpod(keepAlive: true)
LanternService lanternService(Ref ref) {
  return sl<LanternService>();
}
