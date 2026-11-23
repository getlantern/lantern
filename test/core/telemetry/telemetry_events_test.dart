import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/telemetry/telemetry.dart';

void main() {
  test('webview results map to funnel outcomes', () {
    expect(webviewOutcome(true), 'completed');
    expect(webviewOutcome(false), 'cancelled');
    expect(webviewOutcome(null), 'closed');
  });

  test('event tags are unique', () {
    final tags = CheckoutEvent.values.map((e) => e.tag).toList();
    expect(tags.toSet().length, tags.length);
  });

  test(
    'webview close is reported as not observed where the app cannot see it',
    () {
      const open = Duration(seconds: 95);
      expect(
        webviewClosedProperties(
          'shepherd-wechat',
          null,
          open,
          observable: true,
        ),
        {
          'provider': 'shepherd-wechat',
          'outcome': 'closed',
          'seconds_open': 95,
        },
      );
      expect(
        webviewClosedProperties(
          'shepherd-wechat',
          null,
          open,
          observable: false,
        ),
        {
          'provider': 'shepherd-wechat',
          'outcome': 'not_observed',
          'seconds_open': null,
        },
      );
    },
  );
}
