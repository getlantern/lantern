import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/url_utils.dart';

void main() {
  group('UrlUtils.shouldOpenExternallyFromWebView', () {
    test('keeps normal webview schemes inside the webview', () {
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('https://lantern.io/checkout'),
        ),
        isFalse,
      );
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(Uri.parse('about:blank')),
        isFalse,
      );
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('data:text/plain,payment'),
        ),
        isFalse,
      );
    });

    test('opens payment app schemes outside the webview', () {
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('alipays://platformapi/startapp'),
        ),
        isTrue,
      );
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse(
            'intent://platformapi/startapp#Intent;scheme=alipays;package=com.eg.android.AlipayGphone;end',
          ),
        ),
        isTrue,
      );
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('market://details?id=com.eg.android.AlipayGphone'),
        ),
        isTrue,
      );
    });

    test('keeps unrelated custom schemes out of external dispatch', () {
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('mailto:support@lantern.io'),
        ),
        isFalse,
      );
      expect(
        UrlUtils.shouldOpenExternallyFromWebView(
          Uri.parse('whatsapp://send?text=hi'),
        ),
        isFalse,
      );
    });
  });
}
