import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/telemetry/telemetry.dart';

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

  test('values JSON cannot encode are logged as strings', () {
    expect(
      telemetryLine('checkout_started', {'open': const Duration(seconds: 2)}),
      'telemetry event=checkout_started properties={"open":"0:00:02.000000"}',
    );
  });
}
