import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/services/injection_container.dart';
import 'lantern_platform_service.dart';

part 'lantern_service_notifier.g.dart';

@Riverpod(keepAlive: true)
LanternService lanternService(Ref ref) {
  return LanternService(
    ffiService: sl<LanternFFIService>(),
    nativeBridge: sl<LanternPlatformService>(),
  );
}
