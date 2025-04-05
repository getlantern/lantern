import 'package:get_it/get_it.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../router/router.dart';

final GetIt sl = GetIt.instance;

Future<void> injectServices() async {
  sl.registerLazySingleton(() => LanternPlatformService());
  await sl<LanternPlatformService>().init();
  sl.registerLazySingleton(() => LanternFFIService());
  await sl<LanternFFIService>().init();
  sl.registerLazySingleton(() => LocalStorageService());
  await sl<LocalStorageService>().init();
  sl.registerLazySingleton(() => AppRouter());
}
