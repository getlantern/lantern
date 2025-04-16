import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'AppWebview')
class AppWebView extends HookWidget {
  final String title;
  final String url;

  const AppWebView({super.key, required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    final loading = useState(false);
    return BaseScreen(
        title: title,
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                useOnDownloadStart: true,
                useOnLoadResource: true,
                applicationNameForUserAgent: 'Lantern',
              ),
              onWebViewCreated: (controller) {},
              onLoadStart: (_, __) {
                // Handle load start
                loading.value = true;
              },
              onLoadStop: (_, __) {
                // Handle load stop
                loading.value = false;
              },
            ),
            if (loading.value)
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 8.r,
                  color: AppColors.gray1,
                ),
              ),
          ],
        ));
  }
}
