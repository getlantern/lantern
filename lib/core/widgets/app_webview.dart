import 'dart:async';
import 'dart:typed_data';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/deeplink_utils.dart'
    show isOAuthCallbackResult;
import 'package:lantern/core/widgets/loading_indicator.dart';

final webViewLoadingProvider = NotifierProvider<WebViewLoading, bool>(
  WebViewLoading.new,
);

/// Receives main-frame load events from an in-app WebView.
abstract interface class AppWebViewObserver {
  Future<void> onPageLoaded(
    Uri uri, {
    required int documentLength,
    required Future<Uint8List?> Function() captureScreenshot,
    required Future<Object?> Function(String source) evaluateJavaScript,
  });

  void onPageLoadFailed(Uri? uri, String reason);
}

/// Returns the UI handoff result encoded by Lantern's checkout callback.
///
/// Callers must confirm the user's account status with the backend before
/// treating a successful handoff as a completed purchase.
bool? webViewPurchaseResult(Uri uri) {
  if (uri.host != 'lantern.io' && uri.host != 'www.lantern.io') return null;

  var value = uri.queryParameters['purchaseResult'];
  if (value == null && uri.fragment.isNotEmpty) {
    final fragment = uri.fragment;
    final normalized = fragment.startsWith('/?')
        ? fragment.substring(2)
        : fragment.startsWith('?')
        ? fragment.substring(1)
        : fragment;
    try {
      value = Uri.splitQueryString(normalized)['purchaseResult'];
    } on FormatException {
      return null;
    }
  }
  if (value == null) return null;
  return switch (value.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
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
  final AppWebViewObserver? observer;

  const AppWebView({
    super.key,
    required this.title,
    required this.url,
    this.observer,
  });

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
          _InnerWebView(url: url, observer: observer),
          if (isLoading) Center(child: LoadingIndicator()),
        ],
      ),
    );
  }
}

class _InnerWebView extends StatefulHookConsumerWidget {
  final String url;
  final AppWebViewObserver? observer;

  const _InnerWebView({required this.url, this.observer});

  @override
  ConsumerState<_InnerWebView> createState() => _InnerWebViewState();
}

class _InnerWebViewState extends ConsumerState<_InnerWebView> {
  bool _completionHandled = false;

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
        final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
        // WebView2 can report redirected POST navigations as aborted before
        // onLoadStop fires. Consume trusted completion URLs as soon as the
        // navigation starts so the purchase result still reaches the caller.
        if (await _handleCompletionUrl(uri, allowLocalhost: false)) return;
        if (!mounted) return;
        final loading = ref.read(webViewLoadingProvider.notifier);
        loading.start();
      },
      onUpdateVisitedHistory: (_, webUri, _) async {
        final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
        await _handleCompletionUrl(uri, allowLocalhost: false);
      },
      onLoadStop: (controller, webUri) async {
        final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
        if (await _handleCompletionUrl(uri)) return;
        if (!mounted) return;
        ref.read(webViewLoadingProvider.notifier).stop();
        await _reportPageLoaded(controller, uri);
      },
      onReceivedError: (_, webResourceRequest, error) async {
        if (webResourceRequest.isForMainFrame != true) return;
        final uri = Uri.tryParse(webResourceRequest.url.toString());
        if (await _handleCompletionUrl(uri)) return;
        if (!mounted) return;
        ref.read(webViewLoadingProvider.notifier).stop();
        // Intercepting a custom-scheme navigation (e.g. a lantern:// deep
        // link) surfaces as a load error (WebKit err 102 "Frame load
        // interrupted" / "scheme is not HTTP(S)"). That's expected, not a
        // page failure — don't notify the observer.
        final scheme = uri?.scheme ?? '';
        if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
          appLogger.debug(
            'Ignoring benign non-HTTP(S) navigation error for scheme '
            '$scheme: $error',
          );
          return;
        }
        appLogger.error("Received error: $error");
        widget.observer?.onPageLoadFailed(
          uri,
          '${error.type}: ${error.description}',
        );
      },
      onReceivedHttpError: (_, request, response) {
        if (request.isForMainFrame != true) return;
        ref.read(webViewLoadingProvider.notifier).stop();
        final uri = Uri.tryParse(request.url.toString());
        widget.observer?.onPageLoadFailed(uri, 'HTTP ${response.statusCode}');
      },
    );
  }

  Future<void> _reportPageLoaded(
    InAppWebViewController controller,
    Uri? uri,
  ) async {
    final observer = widget.observer;
    if (observer == null || uri == null) return;

    try {
      final value = await controller.evaluateJavascript(
        source: 'document.documentElement?.outerHTML?.length ?? 0',
      );
      final documentLength = value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
      unawaited(_notifyPageLoaded(observer, controller, uri, documentLength));
    } catch (error, stackTrace) {
      appLogger.error('Unable to inspect WebView document', error, stackTrace);
      observer.onPageLoadFailed(uri, error.toString());
    }
  }

  Future<void> _notifyPageLoaded(
    AppWebViewObserver observer,
    InAppWebViewController controller,
    Uri uri,
    int documentLength,
  ) async {
    try {
      await observer.onPageLoaded(
        uri,
        documentLength: documentLength,
        captureScreenshot: () => controller.takeScreenshot(),
        evaluateJavaScript: (source) =>
            controller.evaluateJavascript(source: source),
      );
    } catch (error, stackTrace) {
      appLogger.error('Unable to notify WebView observer', error, stackTrace);
      observer.onPageLoadFailed(uri, error.toString());
    }
  }

  bool isLanternHost(String host) =>
      host == 'lantern.io' || host == 'www.lantern.io';

  Future<bool> _handleCompletionUrl(
    Uri? uri, {
    bool allowLocalhost = true,
  }) async {
    if (_completionHandled) return true;
    if (uri == null) {
      return false;
    }

    // User has completed private server setup.
    if (allowLocalhost &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return _finishCompletion(true);
    }

    // OAuth callback: either a successful login (token) or a device-limit
    // response (result=false plus the device[...] list to de-authorize).
    if (uri.scheme == 'lantern' &&
        uri.host == 'auth' &&
        isOAuthCallbackResult(uri)) {
      return _finishCompletion(uri.queryParameters);
    }

    final purchaseResult = webViewPurchaseResult(uri);
    if (purchaseResult != null) {
      appLogger.info('Webview detected purchase completion on ${uri.host}');
      return _finishCompletion(purchaseResult);
    }

    /// Alipay trade_status=TRADE_SUCCESS once the user has finished paying.
    final tradeStatus = uri.queryParameters['trade_status'];
    if (tradeStatus != null && tradeStatus.toUpperCase() == 'TRADE_SUCCESS') {
      appLogger.info(
        'Webview detected Alipay trade_status=TRADE_SUCCESS on ${uri.host}, closing',
      );
      return _finishCompletion(true);
    }

    if (isLanternHost(uri.host) &&
        uri.path == '/auth' &&
        isOAuthCallbackResult(uri)) {
      return _finishCompletion(uri.queryParameters);
    }

    return false;
  }

  Future<bool> _finishCompletion(Object result) async {
    if (_completionHandled) return true;
    _completionHandled = true;
    if (!mounted) return true;
    ref.read(webViewLoadingProvider.notifier).stop();
    await appRouter.maybePop(result);
    return true;
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
