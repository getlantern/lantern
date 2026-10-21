import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/widgets/app_webview.dart';

class _TestWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _TestWebView(params);
}

class _TestWebView extends PlatformInAppWebViewWidget {
  _TestWebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError();

  @override
  void dispose() {}
}

void main() {
  testWidgets('remote pages disable local file and content access', (
    tester,
  ) async {
    final previousPlatform = InAppWebViewPlatform.instance;
    InAppWebViewPlatform.instance = _TestWebViewPlatform();
    addTearDown(() {
      if (previousPlatform != null) {
        InAppWebViewPlatform.instance = previousPlatform;
      }
    });

    const url = 'https://cloud.digitalocean.com/login';
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppWebView(title: 'DigitalOcean', url: url),
        ),
      ),
    );

    final webView = tester.widget<InAppWebView>(find.byType(InAppWebView));
    final params = webView.platform.params;
    final settings = params.initialSettings!.toMap();
    expect(params.initialUrlRequest!.url.toString(), url);
    expect(settings['allowFileAccess'], isFalse);
    expect(settings['allowContentAccess'], isFalse);
    expect(settings['allowFileAccessFromFileURLs'], isFalse);
    expect(settings['allowUniversalAccessFromFileURLs'], isFalse);
    expect(settings['javaScriptEnabled'], isTrue);
  });

  group('webViewPurchaseResult', () {
    test('reads successful fragment callbacks from Lantern', () {
      expect(
        webViewPurchaseResult(
          Uri.parse('https://lantern.io/#/?purchaseResult=true'),
        ),
        isTrue,
      );
    });

    test('reads canceled query callbacks from Lantern', () {
      expect(
        webViewPurchaseResult(
          Uri.parse('https://www.lantern.io/?purchaseResult=false'),
        ),
        isFalse,
      );
    });

    test('ignores malformed purchase results', () {
      for (final value in ['', 'success', '1']) {
        expect(
          webViewPurchaseResult(
            Uri.https('lantern.io', '/', {'purchaseResult': value}),
          ),
          isNull,
          reason: 'unexpected purchase result: $value',
        );
      }
    });

    test('ignores completion parameters from other hosts', () {
      expect(
        webViewPurchaseResult(
          Uri.parse('https://example.com/#/?purchaseResult=true'),
        ),
        isNull,
      );
    });
  });
}
