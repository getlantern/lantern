import 'package:flutter/services.dart';
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

  group('UrlUtils.authenticateInApp', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('org.getlantern.lantern/method');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void respondWith(String? callback) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'authenticateInApp');
        expect(call.arguments, 'https://df.iantem.io/users/oauth2/google');
        return callback;
      });
    }

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('returns the callback URL', () async {
      respondWith('lantern://auth?token=abc');
      final uri = await UrlUtils.authenticateInApp(
        'https://df.iantem.io/users/oauth2/google',
      );
      expect(uri?.queryParameters, {'token': 'abc'});
    });

    test('returns null when the user closes the sheet', () async {
      respondWith(null);
      final uri = await UrlUtils.authenticateInApp(
        'https://df.iantem.io/users/oauth2/google',
      );
      expect(uri, isNull);
    });
  });
}
