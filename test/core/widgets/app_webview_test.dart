import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/widgets/app_webview.dart';

void main() {
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
