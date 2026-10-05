import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/referral_code.dart';

void main() {
  group('normalizeReferralCode', () {
    test('accepts referral codes and short or hyphenated promo codes', () {
      for (final code in ['PYGFJ4', 'HALF', 'SAVE15', 'SUMMER-20']) {
        expect(normalizeReferralCode(code.toLowerCase()), code);
      }
      expect(normalizeReferralCode('  save15  '), 'SAVE15');
      expect(normalizeReferralCode('A' * 500), 'A' * 500);
    });

    test('rejects invalid input instead of removing characters', () {
      for (final code in [
        '',
        '   ',
        'A' * 501,
        'SAVE 15',
        'SAVE\n15',
        'SAVE\u000015',
        'ſAVE15',
        'ＳＡＶＥ15',
        'SAVE_15',
        'SAVE/15',
        'SAVE%31%35',
        'SAVE15&code=OTHER',
        'LSG_PROBE_1512_HTTPS_AFF_20260918T0608Z:javascript:alert(1)',
      ]) {
        expect(normalizeReferralCode(code), isNull, reason: code);
      }
    });
  });

  group('affiliateCodeFromUri', () {
    test('accepts the supported web and app link forms', () {
      for (final link in [
        'https://lantern.io/affiliate/half',
        'https://www.lantern.io/affiliate/HALF',
        'https://lantern.io:443/affiliate/HALF',
        'https://lantern.io/affiliate/HALF/',
        'https://lantern.io/affiliate?code=half',
        'https://lantern.io/affiliate/?code=HALF',
        'https://lantern.io/affiliate/%48ALF?utm_source=partner',
        'lantern://affiliate/HALF',
        'lantern://affiliate/HALF/',
        'lantern://affiliate?code=HALF',
        'lantern://affiliate/?code=HALF',
      ]) {
        expect(affiliateCodeFromUri(Uri.parse(link)), 'HALF', reason: link);
      }
    });

    test('rejects unsupported origins and routes', () {
      for (final link in [
        'http://lantern.io/affiliate/HALF',
        'https://example.com/affiliate/HALF',
        'https://lantern.io.example.com/affiliate/HALF',
        'https://lantern.io:8443/affiliate/HALF',
        'https://user@lantern.io/affiliate/HALF',
        'https://lantern.io/affiliates/HALF',
        'https://lantern.io/auth?code=HALF',
        'https://lantern.io/affiliate/HALF/extra',
        'https://lantern.io/affiliate//HALF',
        'https://lantern.io/affiliate/HALF#code=OTHER',
        'lantern://other/affiliate/HALF',
        'lantern://affiliate:443/HALF',
        'lantern://user@affiliate/HALF',
        'lantern://affiliate/HALF/extra',
      ]) {
        expect(affiliateCodeFromUri(Uri.parse(link)), isNull, reason: link);
      }
    });

    test('rejects missing, ambiguous, and malformed code values', () {
      for (final base in [
        'https://lantern.io/affiliate',
        'lantern://affiliate',
      ]) {
        for (final suffix in [
          '',
          '/',
          '?code=',
          '?code=HALF&code=OTHER',
          '?code=HALF&code=HALF',
          '?code=HALF&c%6fde=OTHER',
          '/HALF?code=OTHER',
          '/HALF?code=HALF',
          '/%20HALF',
          '?code=HALF%0A',
          '?code=HALF%00',
          '/HALF%2FOTHER',
          '?code=%FF',
          '/%FF',
          '?code=${'A' * 501}',
          '?code=LSG_PROBE_1512_HTTPS_AFF_20260918T0608Z%3Ajavascript%3Aalert%281%29',
        ]) {
          final link = '$base$suffix';
          expect(affiliateCodeFromUri(Uri.parse(link)), isNull, reason: link);
        }
      }
    });
  });
}
