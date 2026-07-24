import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/smoke/payment_checkout_smoke.dart';

void main() {
  group('PaymentCheckoutSmokeConfig', () {
    test('does nothing without smoke arguments', () {
      expect(
        PaymentCheckoutSmokeConfig.parse(
          const [],
          isWindows: true,
          buildType: 'nightly',
        ),
        isNull,
      );
    });

    test('accepts a constrained provider and derives the E2E email', () {
      final config = PaymentCheckoutSmokeConfig.parse(
        const [
          '--payment-checkout-smoke=stripe',
          '--payment-checkout-run-id=9a1632f8-5b33-4d6f-8a42-7a8a4f77d829',
        ],
        isWindows: true,
        buildType: 'nightly',
      );

      expect(config?.provider, 'stripe');
      expect(
        config?.email,
        'e2e+9a1632f8-5b33-4d6f-8a42-7a8a4f77d829@getlantern.org',
      );
    });

    test('accepts the staging-only conversion provider', () {
      final config = PaymentCheckoutSmokeConfig.parse(
        const [
          '--payment-checkout-smoke=e2e',
          '--payment-checkout-run-id=9a1632f8-5b33-4d6f-8a42-7a8a4f77d829',
        ],
        isWindows: true,
        buildType: 'nightly',
      );

      expect(config?.provider, 'e2e');
      expect(config?.completesPurchase, isTrue);
    });

    test('rejects the hook outside a Windows nightly build', () {
      expect(
        () => PaymentCheckoutSmokeConfig.parse(
          const [
            '--payment-checkout-smoke=stripe',
            '--payment-checkout-run-id=9a1632f8-5b33-4d6f-8a42-7a8a4f77d829',
          ],
          isWindows: true,
          buildType: 'production',
        ),
        throwsFormatException,
      );
    });

    test('rejects arbitrary providers and malformed run IDs', () {
      expect(
        () => PaymentCheckoutSmokeConfig.parse(
          const [
            '--payment-checkout-smoke=https://example.com',
            '--payment-checkout-run-id=9a1632f8-5b33-4d6f-8a42-7a8a4f77d829',
          ],
          isWindows: true,
          buildType: 'nightly',
        ),
        throwsFormatException,
      );
      expect(
        () => PaymentCheckoutSmokeConfig.parse(
          const [
            '--payment-checkout-smoke=shepherd',
            '--payment-checkout-run-id=../../unsafe',
          ],
          isWindows: true,
          buildType: 'nightly',
        ),
        throwsFormatException,
      );
      expect(
        () => PaymentCheckoutSmokeConfig.parse(
          const [
            '--payment-checkout-smoke=',
            '--payment-checkout-run-id=9a1632f8-5b33-4d6f-8a42-7a8a4f77d829',
          ],
          isWindows: true,
          buildType: 'nightly',
        ),
        throwsFormatException,
      );
    });
  });
}
