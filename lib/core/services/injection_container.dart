import 'package:get_it/get_it.dart';
import 'package:lantern/core/services/local_storage.dart';

import '../router/router.dart';

final GetIt sl = GetIt.instance;

void injectServices() {
  sl.registerLazySingleton(() => AppRouter());
  sl.registerLazySingleton(() => LocalStorageService());
  sl<LocalStorageService>().init();
}
