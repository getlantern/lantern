import 'package:get_it/get_it.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/core/services/stripe_service.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/core/utils/store_utils.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:lantern/lantern/lantern_service.dart';

import '../router/router.dart';
import 'logger_service.dart';

final GetIt sl = GetIt.instance;

Future<void> injectServices() async {
  appLogger.debug('Initializing storage services...');
  final storage = LocalStorageService();
  final storeUtils = StoreUtils();
  try {
    await Future.wait([storage.init(), storeUtils.init()]);
    appLogger.debug('Storage services initialized');
  } catch (e, st) {
    appLogger.error('Storage init failed', e, st);
  }
  sl.registerSingleton<LocalStorageService>(storage);
  sl.registerSingleton<StoreUtils>(storeUtils);

  sl.registerLazySingleton<Updater>(() => Updater());
  sl.registerLazySingleton<AppRouter>(() => AppRouter());
  sl.registerLazySingleton<DeepLinkCallbackManager>(
    () => DeepLinkCallbackManager(),
  );

  appLogger.debug('Initializing AppPurchase...');
  final appPurchase = AppPurchase();
  appPurchase.init();
  sl.registerSingleton<AppPurchase>(appPurchase);
  appLogger.debug('AppPurchase initialized');

  sl.registerSingleton<LanternPlatformService>(LanternPlatformService());
  sl.registerSingleton<LanternFFIService>(
    PlatformUtils.isFFISupported
        ? LanternFFIService()
        : MockLanternFFIService(),
  );

  final lanternService = LanternService(
    ffiService: sl<LanternFFIService>(),
    platformService: sl<LanternPlatformService>(),
    appPurchase: sl<AppPurchase>(),
  );
  await lanternService.init();
  appLogger.debug('LanternService initialized');
  sl.registerSingleton<LanternService>(lanternService);

  appLogger.debug('Initializing notification/Stripe services...');
  final notificationService = NotificationService();
  try {
    if (PlatformUtils.isAndroid) {
      final stripeService = StripeService();
      await Future.wait([
        notificationService.init(),
        stripeService.initialize(),
      ]);
      sl.registerSingleton<StripeService>(stripeService);
      appLogger.debug('StripeService initialized');
    } else {
      await notificationService.init();
    }
  } catch (e, st) {
    appLogger.error('Notification/Stripe init failed', e, st);
  }
  sl.registerSingleton<NotificationService>(notificationService);
  appLogger.debug('NotificationService initialized');

  appLogger.info('All services injected ✅');
}
