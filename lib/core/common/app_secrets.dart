import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppSecrets {
  static String get macosAppGroupId => dotenv.env['MACOS_APP_GROUP'] ?? '';
}
