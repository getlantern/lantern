import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/widgets/logs_path.dart';

void main() {
  const cdn = 'https://lantern-cloud-images.web.app/payments/v1';

  test('known payment icons resolve to bundled assets that exist', () {
    for (final name in [
      'alipay',
      'mastercard',
      'unionpay',
      'visa',
      'wechatpay',
    ]) {
      final asset = bundledPaymentIcon('$cdn/$name.svg');
      expect(asset, 'assets/images/payments/$name.svg');
      expect(File(asset!).existsSync(), isTrue, reason: asset);
    }
  });

  test('unknown icons fall back to the network', () {
    expect(bundledPaymentIcon('$cdn/qiwi.svg'), isNull);
    expect(bundledPaymentIcon('$cdn/wechatpay.png'), isNull);
    expect(bundledPaymentIcon('not a url'), isNull);
  });
}
