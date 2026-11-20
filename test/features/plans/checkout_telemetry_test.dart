import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/features/plans/checkout_telemetry.dart';

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
}
