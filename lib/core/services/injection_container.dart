import 'package:get_it/get_it.dart';

import '../router/router.dart';

final GetIt sl = GetIt.instance;

void injectServices(){
  sl.registerLazySingleton(() => AppRouter());
}