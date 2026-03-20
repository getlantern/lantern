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

}
