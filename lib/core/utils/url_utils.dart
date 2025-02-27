import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    print('Could not launch $url');
  }
}
