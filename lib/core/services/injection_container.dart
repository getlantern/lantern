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
    sl.registerSingletonAsync<StoreUtils>(() async {
      appLogger.info("Initializing StoreUtils");
      final storeUtils = StoreUtils();
      await storeUtils.init();
      return storeUtils;
    });

    sl.registerLazySingleton(() => AppPurchase());
    sl<AppPurchase>().init();
    sl.registerLazySingleton<DeepLinkCallbackManager>(
        () => DeepLinkCallbackManager());
    // We want to make sure the platform service and FFI service are
    // initialized as early as possible so we can communicate with
    // native code on different platforms.
    final ps = LanternPlatformService();
    await ps.init();
    sl.registerSingleton<LanternPlatformService>(ps);

    if (PlatformUtils.isFFISupported) {
      sl.registerLazySingleton(() => LanternFFIService());
      await sl<LanternFFIService>().init();
    } else {
      sl.registerLazySingleton<LanternFFIService>(
          () => MockLanternFFIService());
    }
    sl.registerLazySingleton(() => LocalStorageService());
    await sl<LocalStorageService>().init();
    sl.registerLazySingleton(() => AppRouter());

    if (PlatformUtils.isAndroid) {
      sl.registerSingletonAsync<StripeService>(() async {
        appLogger.info("Initializing StripeService");
        final stripeService = StripeService();
        await stripeService.initialize();
        return stripeService;
      });
    }
    sl.registerSingletonAsync<NotificationService>(() async {
      appLogger.info("Initializing NotificationService");
      final notificationService = NotificationService();
      await notificationService.init();
      return notificationService;
    });
    appLogger.info("All services injected ✅");
  } catch (e, st) {
    appLogger.error("Error during service injection", e, st);
  }
}
