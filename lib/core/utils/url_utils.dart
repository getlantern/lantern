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

  static Future<T?> openWebview<T>(
      String url, {
        String? title,
        Function(T)? onWebviewResult,
      }) async {
    try {
      switch (Platform.operatingSystem) {
        case 'android':
        case 'ios':
        case 'macos':
        case 'windows':
          final result = await appRouter.push<T>(
            AppWebview(title: title ?? '', url: url),
          );
          if (result != null) {
            onWebviewResult?.call(result);
          }
          return result;

        case 'linux':
          final webview = await WebviewWindow.create();
          webview.launch(url);
          return null;

        default:
          throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
      }
    } catch (e, st) {
      appLogger.error("Failed to open webview", e, st);
      return null;
    }
  }

  // static Future<void> openWebview(String url,
  //     {String? title, Function(dynamic)? onBackPressed}) async {
  //   try {
  //     switch (Platform.operatingSystem) {
  //       case 'android':
  //       case 'macos':
  //       case 'ios':
  //       case 'windows':
  //         appRouter
  //             .push(AppWebview(title: title ?? '', url: url))
  //             .then((value) {
  //           if (value != null && onBackPressed != null) {
  //             onBackPressed.call(value);
  //           }
  //         });
  //         break;
  //       case 'linux':
  //         final webview = await WebviewWindow.create();
  //         webview.launch(url);
  //         break;
  //       default:
  //         throw UnsupportedError('Platform not supported');
  //     }
  //   } catch (e) {
  //     appLogger.error("Failed to open webview", e);
  //   }
  // }

  static bool isValidDomain(String input) {
    final domainPattern = r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.[A-Za-z]{2,6}$';
    return RegExp(domainPattern).hasMatch(input);
  }

  static bool isValidIPv4(String input) {
    final pattern = r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$';
    final segments = input.split('.');
    return RegExp(pattern).hasMatch(input) &&
        segments.every((s) => int.parse(s) <= 255);
  }

  static bool isValidDomainOrIP(String input) =>
      isValidDomain(input) || isValidIPv4(input);

  static String extractDomain(String input) {
    var formatted = input;
    if (!formatted.startsWith("http://") && !formatted.startsWith("https://")) {
      formatted = "https://$formatted";
    }

    final uri = Uri.parse(formatted);
    final parts = uri.host.split('.');
    return parts.length > 2
        ? "${parts[parts.length - 2]}.${parts.last}"
        : uri.host;
  }
}
