import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';

final webViewLoadingProvider =
    NotifierProvider<WebViewLoading, bool>(WebViewLoading.new);

class WebViewLoading extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void stop() => state = false;
}

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
          backgroundColor: context.bgElevated,
          iconTheme: IconThemeData(color: context.textPrimary),
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
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    useOnDownloadStart: true,
    useOnLoadResource: true,
    applicationNameForUserAgent: 'Lantern',
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
      onCreateWindow: (controller, createWindowAction) async {
        final req = createWindowAction.request;
        if (req.url != null) {
          await controller.loadUrl(urlRequest: req);
          return true;
        }
        return false;
      },
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
        ref.read(webViewLoadingProvider.notifier).state = false;

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
    if (uri == null) return NavigationActionPolicy.ALLOW;

    final u = Uri.parse(uri.toString());

    bool isLanternHost(String host) =>
        host == 'lantern.io' || host == 'www.lantern.io';

    // Collect purchaseResult from query
    String? purchaseResult = u.queryParameters['purchaseResult'];

    // Handle fragment like "#/?purchaseResult=true" or "#purchaseResult=true"
    if (purchaseResult == null && u.fragment.isNotEmpty) {
      final frag = u.fragment;

      final normalized = frag.startsWith('/?')
          ? frag.substring(2)
          : frag.startsWith('?')
              ? frag.substring(1)
              : frag;

      try {
        final fragParams = Uri.splitQueryString(normalized);
        purchaseResult = fragParams['purchaseResult'];
      } catch (_) {}
    }

    if (purchaseResult != null && isLanternHost(u.host)) {
      await appRouter.maybePop(purchaseResult.toLowerCase() == 'true');
      return NavigationActionPolicy.CANCEL;
    }

    if (isLanternHost(u.host) && (u.path == '/' || u.path.isEmpty)) {
      return NavigationActionPolicy.ALLOW;
    }

    if (isLanternHost(u.host) &&
        u.path == '/auth' &&
        u.queryParameters.containsKey('token')) {
      await appRouter.maybePop(u.queryParameters);
      return NavigationActionPolicy.CANCEL;
    }

    appLogger.debug("shouldOverrideUrlLoading: $uri");

    return NavigationActionPolicy.ALLOW;
  }
}
