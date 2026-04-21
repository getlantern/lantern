import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';

final webViewLoadingProvider = NotifierProvider<WebViewLoading, bool>(
  WebViewLoading.new,
);

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
      ),
    );
  }
}

class _InnerWebView extends StatefulHookConsumerWidget {
  final String url;

  const _InnerWebView({required this.url});

  @override
  ConsumerState<_InnerWebView> createState() => _InnerWebViewState();
}

class _InnerWebViewState extends ConsumerState<_InnerWebView> {
  final setting = InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    supportMultipleWindows: true,
    // On Windows, plugin-level URL interception can break complex payment flows.
    // We still detect completion URLs in load callbacks.
    useShouldOverrideUrlLoading: !PlatformUtils.isWindows,
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
        if (PlatformUtils.isWindows) {
          // On Windows, Stripe/Alipay flows may open popups with window.open.
          // If we return true here without creating a real popup WebView,
          // the navigation can hang and show a blank page.
          return false;
        }
        if (req.url != null) {
          await controller.loadUrl(urlRequest: req);
          return true;
        }
        return false;
      },
      onLoadStart: (_, webUri) async {
        // Handle load start
        final loading = ref.read(webViewLoadingProvider.notifier);
        loading.start();
      },
      onLoadStop: (controller, webUri) async {
        // Handle load stop
        ref.read(webViewLoadingProvider.notifier).stop();
        await _handleCompletionUrl(
          webUri == null ? null : Uri.tryParse(webUri.toString()),
        );
      },
      onReceivedError: (_, webResourceRequest, error) async {
        // Handle received error
        appLogger.error("Received error: $error");
        // Handle load stop
        ref.read(webViewLoadingProvider.notifier).stop();
        await _handleCompletionUrl(
          Uri.tryParse(webResourceRequest.url.toString()),
        );
      },
    );
  }

  bool isLanternHost(String host) =>
      host == 'lantern.io' || host == 'www.lantern.io';

  String? _extractPurchaseResult(Uri uri) {
    var purchaseResult = uri.queryParameters['purchaseResult'];
    if (purchaseResult != null) {
      return purchaseResult;
    }

    if (uri.fragment.isEmpty) {
      return null;
    }

    final frag = uri.fragment;
    final normalized = frag.startsWith('/?')
        ? frag.substring(2)
        : frag.startsWith('?')
        ? frag.substring(1)
        : frag;

    try {
      final fragParams = Uri.splitQueryString(normalized);
      return fragParams['purchaseResult'];
    } catch (_) {
      return null;
    }
  }

  Future<bool> _handleCompletionUrl(Uri? uri) async {
    if (uri == null) {
      return false;
    }

    final loading = ref.read(webViewLoadingProvider.notifier);

    // User has completed private server setup.
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      loading.stop();
      await appRouter.maybePop(true);
      return true;
    }

    // OAuth callback.
    if (uri.scheme == 'lantern' &&
        uri.host == 'auth' &&
        uri.queryParameters.containsKey('token')) {
      loading.stop();
      await appRouter.maybePop(uri.queryParameters);
      return true;
    }

    final purchaseResult = _extractPurchaseResult(uri);
    if (purchaseResult != null && isLanternHost(uri.host)) {
      loading.stop();
      await appRouter.maybePop(purchaseResult.toLowerCase() == 'true');
      return true;
    }

    if (isLanternHost(uri.host) &&
        uri.path == '/auth' &&
        uri.queryParameters.containsKey('token')) {
      loading.stop();
      await appRouter.maybePop(uri.queryParameters);
      return true;
    }

    return false;
  }

  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    final u = Uri.tryParse(uri.toString());
    if (u == null) {
      return NavigationActionPolicy.ALLOW;
    }

    // Allow localhost requests to go through so the local server actually
    // receives the callback (e.g. private server auth).
    if (u.host == 'localhost' || u.host == '127.0.0.1') {
      return NavigationActionPolicy.ALLOW;
    }

    final handled = await _handleCompletionUrl(u);
    if (handled) {
      return NavigationActionPolicy.CANCEL;
    }

    if (isLanternHost(u.host) && (u.path == '/' || u.path.isEmpty)) {
      return NavigationActionPolicy.ALLOW;
    }

    appLogger.debug("shouldOverrideUrlLoading: $uri");

    return NavigationActionPolicy.ALLOW;
  }
}
