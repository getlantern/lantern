import 'package:get_it/get_it.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_native_bridge.dart';
import 'package:lantern/lantern/lantern_service.dart';

import '../router/router.dart';

final GetIt sl = GetIt.instance;

Future<void> injectServices() async {
  sl.registerLazySingleton(() => AppRouter());
  sl.registerLazySingleton(() => LocalStorageService());
  await sl<LocalStorageService>().init();

  ///Services
  sl.registerLazySingleton(() => LanternNativeBridge());
  sl.registerLazySingleton(() => LanternFFIService());
  sl.registerLazySingleton(
    () => LanternService(
      ffiService: sl<LanternFFIService>(),
      nativeBridge: sl<LanternNativeBridge>(),
    ),
  );
}
