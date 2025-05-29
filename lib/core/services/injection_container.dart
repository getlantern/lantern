import 'package:get_it/get_it.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/core/utils/store_utils.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../router/router.dart';

final GetIt sl = GetIt.instance;

Future<void> injectServices() async {
  if (PlatformUtils.isAndroid) {
    sl.registerLazySingleton(() => StoreUtils());
    sl<StoreUtils>().init();
  }

  sl.registerLazySingleton(() => AppPurchase());
  sl<AppPurchase>().init();

  sl.registerLazySingleton(() => NotificationService());
  await sl<NotificationService>().init();

  sl.registerLazySingleton(() => LanternPlatformService(sl<AppPurchase>()));
  await sl<LanternPlatformService>().init();
  if (PlatformUtils.isDesktop) {
    sl.registerLazySingleton(() => LanternFFIService());
    await sl<LanternFFIService>().init();
  } else {
    sl.registerLazySingleton<LanternFFIService>(() => MockLanternFFIService());
  }
  sl.registerLazySingleton(() => LocalStorageService());
  await sl<LocalStorageService>().init();
  sl.registerLazySingleton(() => AppRouter());
  sl.registerLazySingleton(() => StripeService());
  await sl<StripeService>().initialize();

  sl.registerLazySingleton(() => DeepLinkCallbackManager());
}
