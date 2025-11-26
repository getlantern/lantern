import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppSecrets {
  static String get macosAppGroupId => dotenv.env['MACOS_APP_GROUP'] ?? '';

  static String get stripeTestPublishableKey =>
      dotenv.env['STRIPE_TEST_PUBLISHABLE_KEY'] ?? '';

  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  static String get windowsAppUserModelId =>
      dotenv.env['WINDOWS_APP_USER_MODEL_ID'] ?? '';

  static String get windowsGuid => dotenv.env['WINDOWS_GUID'] ?? '';

  static String get lanternPackageName => "org.getlantern.lantern";

  static String dnsConfig() {
    if (Platform.isAndroid) {
      return "https://4753d78f885f4b79a497435907ce4210@o75725.ingest.sentry.io/5850353";
    }
    if (Platform.isIOS) {
      return "https://c14296fdf5a6be272e1ecbdb7cb23f76@o75725.ingest.sentry.io/4506081382694912";
    }
    return "https://7397d9db6836eb599f41f2c496dee648@o75725.ingest.us.sentry.io/4507734480912384";
  }
}
