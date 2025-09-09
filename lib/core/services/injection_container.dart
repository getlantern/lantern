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
import 'logger_service.dart';

final GetIt sl = GetIt.instance;

Future<void> injectServices() async {
  try {
    sl.registerLazySingleton<AppPurchase>(() {
      final ap = AppPurchase();
      ap.init();
      return ap;
    });

    // We want to make sure the platform service and FFI service are
    // initialized as early as possible so we can communicate with 
    // native code on different platforms.
    final ps = LanternPlatformService();
    await ps.init();
    sl.registerSingleton<LanternPlatformService>(ps);
    final LanternFFIService ffiService;
    if (PlatformUtils.isFFISupported) {
      ffiService = LanternFFIService();
      await ffiService.init();
    } else {
      ffiService = MockLanternFFIService();
    }
    sl.registerSingleton<LanternFFIService>(ffiService);
    sl.registerLazySingleton<LocalStorageService>(() {
      final localStorage = LocalStorageService();
      localStorage.init();
      return localStorage;
    });
    sl.registerLazySingleton<AppRouter>(() => AppRouter());


    sl.registerLazySingleton<StoreUtils>(() {
      final storeUtils = StoreUtils();
      storeUtils.init();
      return storeUtils;
    });
    sl.registerLazySingleton<StripeService>(() {
      final stripeService = StripeService();
      stripeService.initialize();
      return stripeService;
    });
    sl.registerLazySingleton<DeepLinkCallbackManager>(() => DeepLinkCallbackManager());
    sl.registerLazySingleton<NotificationService>(() {
      final notificationService = NotificationService();
      notificationService.init();
      return notificationService;
    });
  } catch (e, st) {
    appLogger.error("Error during service injection", e, st);
  }
}