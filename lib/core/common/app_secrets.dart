import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppSecrets {
  static String macosAppGroupId = dotenv.env['MACOS_APP_GROUP'] ?? '';
}
