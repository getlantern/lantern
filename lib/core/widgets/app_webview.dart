import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';

final webViewLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

@RoutePage(name: 'AppWebview')
class AppWebView extends HookConsumerWidget {
  final String title;
  final String url;

  const AppWebView({super.key, required this.title, required this.url});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(webViewLoadingProvider);
    return BaseScreen(
        title: "",
        padded: false,
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          leading: SizedBox(),
          backgroundColor: AppColors.white,
          iconTheme: IconThemeData(color: AppColors.black),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                appRouter.maybePop();
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            _InnerWebView(url: url),
            if (isLoading) Center(child: LoadingIndicator()),
          ],
        ));
  }
}

class _InnerWebView extends StatefulHookConsumerWidget {
  final String url;

  const _InnerWebView({
    required this.url,
  });

  @override
  ConsumerState<_InnerWebView> createState() => _InnerWebViewState();
}

class _InnerWebViewState extends ConsumerState<_InnerWebView> {
  final setting = InAppWebViewSettings(
    javaScriptEnabled: true,
    mediaPlaybackRequiresUserGesture: false,
    useOnDownloadStart: true,
    useOnLoadResource: true,
    applicationNameForUserAgent: 'Lantern',
    useShouldOverrideUrlLoading: true,
    hardwareAcceleration: true,
    // userAgent: _getUserAgent(),
    supportZoom: true,
    preferredContentMode: UserPreferredContentMode.DESKTOP,
  );
  late final URLRequest _initialRequest;

  @override
  void initState() {
    super.initState();
    _initialRequest = URLRequest(url: WebUri(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    appLogger.debug("Building _InnerWebView with URL: ${widget.url}");
    return InAppWebView(
      key: const ValueKey('app-webview'),
      shouldOverrideUrlLoading: shouldOverrideUrlLoading,
      initialUrlRequest: _initialRequest,
      initialSettings: setting,
      onWebViewCreated: (controller) {},
      onLoadStart: (_, __) {
        // Handle load start
        ref.read(webViewLoadingProvider.notifier).state = true;
      },
      onLoadStop: (controller, webUri) {
        // Handle load stop
        ref.read(webViewLoadingProvider.notifier).state = false;
        final url = webUri;

        ///User has completed that private server setup
        if (url?.host == 'localhost' || url?.host == '127.0.0.1') {
          appRouter.maybePop(true);
        }
      },
      onReceivedError: (_, webResourceRequest, error) {
        // Handle received error
        appLogger.error("Received error: $error");
        // Handle load stop
        ref.read(webViewLoadingProvider.notifier).state = true;

        final url = webResourceRequest.url;

        ///User has completed that private server setup
        if (url.host == 'localhost') {
          appRouter.maybePop(true);
        }
      },
    );
  }

  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;
    if (uri?.rawValue == "https://lantern.io/") {
      return NavigationActionPolicy.CANCEL;
    }
    if (uri?.fragment.contains('purchaseResult=') ?? false) {
      final normalized = uri.toString().replaceFirst(RegExp(r'#\/\?'), '?');
      final uri2 = Uri.parse(normalized);
      final result = uri2.queryParameters['purchaseResult'];
      await appRouter.maybePop(bool.parse(result ?? 'false'));
      return NavigationActionPolicy.CANCEL;
    } else if (uri?.host == 'www.lantern.io' &&
        uri?.path == '/auth' &&
        uri!.queryParameters.containsKey('token')) {
      appRouter.navigatorKey.currentContext
          ?.showSnackBar("Successfully logged in");
      // User has successfully logged in to google or apple
      await appRouter.maybePop(uri.queryParameters);

      return NavigationActionPolicy.CANCEL;
    }
    appLogger.debug("shouldOverrideUrlLoading: $uri");
    return NavigationActionPolicy.ALLOW;
  }
}
