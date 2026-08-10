import 'dart:async';
import 'dart:typed_data';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/loading_indicator.dart';

final webViewLoadingProvider = NotifierProvider<WebViewLoading, bool>(
  WebViewLoading.new,
);

/// Last main-frame load event from an in-app WebView. Smoke tests (and any
/// future load-error UI) watch this to observe page loads inside the native
/// view, which widget finders cannot see into.
final webViewPageEventProvider =
    NotifierProvider<WebViewPageEvents, WebViewPageEvent?>(
      WebViewPageEvents.new,
    );

sealed class WebViewPageEvent {
  const WebViewPageEvent(this.uri);

  final Uri? uri;
}

class WebViewPageLoaded extends WebViewPageEvent {
  const WebViewPageLoaded(
    Uri super.uri, {
    required this.documentLength,
    required this.captureScreenshot,
  });

  final int documentLength;

  /// Captures the live WebView content; only valid while the page is up.
  final Future<Uint8List?> Function() captureScreenshot;
}

class WebViewPageLoadFailed extends WebViewPageEvent {
  const WebViewPageLoadFailed(super.uri, this.reason);

  final String reason;
}

class WebViewPageEvents extends Notifier<WebViewPageEvent?> {
  @override
  WebViewPageEvent? build() => null;

  void report(WebViewPageEvent event) => state = event;
}

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
    preferredContentMode: PlatformUtils.isMobile
        ? UserPreferredContentMode.MOBILE
        : UserPreferredContentMode.DESKTOP,
  );
  late final URLRequest _initialRequest;

  @override
  void initState() {
    super.initState();
    _initialRequest = URLRequest(url: WebUri(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final initialUri = Uri.tryParse(widget.url);
    appLogger.debug(
      'Building _InnerWebView for host: ${initialUri?.host ?? '<none>'}',
    );
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
          final uri = Uri.tryParse(req.url.toString());
          if (uri != null && await _consumeExternalAppUrlIfNeeded(uri)) {
            return true;
          }
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
        ref.read(webViewLoadingProvider.notifier).stop();
        final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
        await _reportPageLoaded(controller, uri);
        await _handleCompletionUrl(uri);
      },
      onReceivedError: (_, webResourceRequest, error) async {
        appLogger.error("Received error: $error");
        ref.read(webViewLoadingProvider.notifier).stop();
        final uri = Uri.tryParse(webResourceRequest.url.toString());
        if (webResourceRequest.isForMainFrame == true) {
          ref
              .read(webViewPageEventProvider.notifier)
              .report(
                WebViewPageLoadFailed(
                  uri,
                  '${error.type}: ${error.description}',
                ),
              );
        }
        await _handleCompletionUrl(uri);
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame != true) return;
        ref.read(webViewLoadingProvider.notifier).stop();
        final uri = Uri.tryParse(request.url.toString());
        ref
            .read(webViewPageEventProvider.notifier)
            .report(WebViewPageLoadFailed(uri, 'HTTP ${response.statusCode}'));
      },
    );
  }

  Future<void> _reportPageLoaded(
    InAppWebViewController controller,
    Uri? uri,
  ) async {
    if (uri == null) return;

    try {
      final value = await controller.evaluateJavascript(
        source: 'document.documentElement?.outerHTML?.length ?? 0',
      );
      final documentLength = value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
      if (!mounted) return;
      ref
          .read(webViewPageEventProvider.notifier)
          .report(
            WebViewPageLoaded(
              uri,
              documentLength: documentLength,
              captureScreenshot: () => controller.takeScreenshot(),
            ),
          );
    } catch (error, stackTrace) {
      appLogger.error('Unable to inspect WebView document', error, stackTrace);
      if (!mounted) return;
      ref
          .read(webViewPageEventProvider.notifier)
          .report(WebViewPageLoadFailed(uri, error.toString()));
    }
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

    /// Alipay trade_status=TRADE_SUCCESS once the user has finished paying.
    final tradeStatus = uri.queryParameters['trade_status'];
    if (tradeStatus != null && tradeStatus.toUpperCase() == 'TRADE_SUCCESS') {
      appLogger.info(
        'Webview detected Alipay trade_status=TRADE_SUCCESS on ${uri.host}, closing',
      );
      loading.stop();
      await appRouter.maybePop(true);
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

    if (await _consumeExternalAppUrlIfNeeded(u)) {
      return NavigationActionPolicy.CANCEL;
    }

    if (isLanternHost(u.host) && (u.path == '/' || u.path.isEmpty)) {
      return NavigationActionPolicy.ALLOW;
    }

    appLogger.debug("shouldOverrideUrlLoading: $uri");

    return NavigationActionPolicy.ALLOW;
  }

  Future<bool> _consumeExternalAppUrlIfNeeded(Uri uri) async {
    if (!UrlUtils.shouldOpenExternallyFromWebView(uri)) {
      return false;
    }

    ref.read(webViewLoadingProvider.notifier).stop();
    final launched = await UrlUtils.tryLaunchExternalAppUrl(context, uri);
    final host = uri.host.isEmpty ? '<none>' : uri.host;
    if (launched) {
      appLogger.info(
        'Webview opened external app URL: scheme=${uri.scheme}, host=$host',
      );
    } else {
      appLogger.warning(
        'Webview could not open external app URL: scheme=${uri.scheme}, host=$host',
      );
    }
    return true;
  }
}
