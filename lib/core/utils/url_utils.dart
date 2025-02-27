import 'package:lantern/core/services/logger_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      appLogger.error('Could not launch $url');
    }
  }
}
