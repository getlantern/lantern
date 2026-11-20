import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/telemetry.dart';

void main() {
  test('telemetry lines drop null properties and encode the rest as JSON', () {
    expect(
      telemetryLine('checkout_started', {
        'provider': 'shepherd-wechat',
        'plan': null,
        'methods': ['shepherd-wechat', 'stripe'],
        'seconds_open': 42,
      }),
      'telemetry event=checkout_started properties='
      '{"provider":"shepherd-wechat","methods":["shepherd-wechat","stripe"],'
      '"seconds_open":42}',
    );
  });
}
