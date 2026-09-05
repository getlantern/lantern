import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/country_code.dart';

void main() {
  group('CountryCode regions', () {
    test('every external-payment region is also a censored region', () {
      // The exemption only matters where Play Billing is unreachable; a
      // non-censored entry here would silently divert a working market to
      // the external payment path.
      for (final code in CountryCode.externalPaymentRegions) {
        expect(
          CountryCode.censoredRegions,
          contains(code),
          reason: '$code is exempt from Play billing but not censored',
        );
      }
    });

    test('CN and IR stay on the store path', () {
      expect(CountryCode.externalPaymentRegions, isNot(contains('CN')));
      expect(CountryCode.externalPaymentRegions, isNot(contains('IR')));
    });
  });
}
