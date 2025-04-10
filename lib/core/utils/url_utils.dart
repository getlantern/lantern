import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lantern/core/common/common.dart';
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

  // openWithSystemBrowser opens a URL in the browser
  static Future<void> openWithSystemBrowser(String url) async {
    switch (Platform.operatingSystem) {
      case 'linux':
        final webview = await WebviewWindow.create();
        webview.launch(url);
        break;
      default:
        await InAppBrowser.openWithSystemBrowser(url: WebUri(url));
    }
  }

  static Future<void> openWebview(String url, [String? title]) async {
    try {
      switch (Platform.operatingSystem) {
        case 'android':
        case 'macos':
        case 'ios':
        case 'windows':
          appRouter.push(AppWebview(title: title ?? '', url: url));
          break;
        case 'linux':
          final webview = await WebviewWindow.create();
          webview.launch(url);
          break;
        default:
          throw UnsupportedError('Platform not supported');
      }
    } catch (e) {
      appLogger.error("Failed to open webview", e);
    }
  }
}
