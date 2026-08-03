import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/app_webview_environment.dart';
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
        fit: StackFit.expand,
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
    applicationNameForUserAgent: 'Lantern',
    hardwareAcceleration: true,
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
    if (PlatformUtils.isWindows && AppWebViewEnvironment.environment == null) {
      _logSmokeEvent(
        'creation_error',
        Uri.tryParse(widget.url),
        detail: 'stage=environment',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isWindows && AppWebViewEnvironment.environment == null) {
      return Center(
        child: Text(
          'Unable to open this page.',
          style: TextStyle(color: context.textPrimary),
        ),
      );
    }

    final initialUri = Uri.tryParse(widget.url);
    appLogger.debug(
      'Building _InnerWebView for host: ${initialUri?.host ?? '<none>'}',
    );
    return InAppWebView(
      key: const ValueKey('app-webview'),
      webViewEnvironment: AppWebViewEnvironment.environment,
      shouldOverrideUrlLoading: shouldOverrideUrlLoading,
      initialUrlRequest: _initialRequest,
      initialSettings: setting,
      onWebViewCreated: (_) {
        final uri = Uri.tryParse(widget.url);
        _logSmokeEvent('created', uri);
      },
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
        final loading = ref.read(webViewLoadingProvider.notifier);
        loading.start();
        _logSmokeEvent(
          'load_start',
          webUri == null ? null : Uri.tryParse(webUri.toString()),
        );
      },
      onLoadStop: (controller, webUri) async {
        ref.read(webViewLoadingProvider.notifier).stop();
        final uri = webUri == null ? null : Uri.tryParse(webUri.toString());
        var documentLength = -1;
        try {
          final rawLength = await controller.evaluateJavascript(
            source:
                "(document.documentElement && document.documentElement.outerHTML || '').length",
          );
          final parsedLength = rawLength is num
              ? rawLength.toInt()
              : int.tryParse(rawLength.toString());
          if (parsedLength == null) {
            _logSmokeEvent(
              'document_error',
              uri,
              detail: 'reason=invalid_document_length',
            );
          } else {
            documentLength = parsedLength;
          }
        } catch (_) {
          _logSmokeEvent(
            'document_error',
            uri,
            detail: 'reason=evaluate_javascript_failed',
          );
        }
        _logSmokeEvent(
          'load_stop',
          uri,
          detail: 'document_length=$documentLength',
        );
        await _handleCompletionUrl(uri);
      },
      onReceivedError: (_, webResourceRequest, error) async {
        final uri = Uri.tryParse(webResourceRequest.url.toString());
        final isMainFrame = webResourceRequest.isForMainFrame == true;
        appLogger.error(
          'WebView request failed: type=${error.type} '
          'main_frame=$isMainFrame host=${uri?.host ?? '<none>'}',
        );
        _logSmokeEvent(
          isMainFrame ? 'navigation_error' : 'resource_error',
          uri,
          detail: 'error_type=${error.type}',
        );
        if (isMainFrame) {
          ref.read(webViewLoadingProvider.notifier).stop();
          await _handleCompletionUrl(uri);
        }
      },
      onReceivedHttpError: (_, webResourceRequest, errorResponse) async {
        if (webResourceRequest.isForMainFrame != true) return;
        _logSmokeEvent(
          'navigation_error',
          Uri.tryParse(webResourceRequest.url.toString()),
          detail: 'http_status=${errorResponse.statusCode}',
        );
      },
      onProcessFailed: (_, detail) {
        if (!PlatformUtils.isWindows) return;
        ref.read(webViewLoadingProvider.notifier).stop();
        appLogger.error('WebView2 process failed: ${detail.kind}');
        _logSmokeEvent(
          'process_error',
          Uri.tryParse(widget.url),
          detail: 'kind=${detail.kind}',
        );
      },
    );
  }

  void _logSmokeEvent(String event, Uri? uri, {String detail = ''}) {
    if (!PlatformUtils.isWindows || AppBuildInfo.buildType != 'nightly') {
      return;
    }
    // Checkout paths and query strings can contain session tokens. The origin
    // is enough to prove which provider loaded without putting them in CI logs.
    final port = uri?.hasPort == true ? ':${uri!.port}' : '';
    final safeUri = uri == null ? '<none>' : '${uri.scheme}://${uri.host}$port';
    final suffix = detail.isEmpty ? '' : ' $detail';
    appLogger.info(
      'PAYMENT_WEBVIEW_SMOKE event=$event host=${uri?.host ?? '<none>'} '
      'url=$safeUri$suffix',
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
