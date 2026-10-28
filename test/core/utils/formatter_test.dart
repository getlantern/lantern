import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/formatter.dart';

void main() {
  const code = '2346789BCDFGHJKMPQRTVWXY2';
  const formatted = '23467-89BCD-FGHJK-MPQRT-VWXY2';

  group('isWebLicenseKey', () {
    test('detects the PRO prefix or suffix', () {
      expect(isWebLicenseKey('PRO-$formatted'), isTrue);
      expect(isWebLicenseKey('$formatted-PRO'), isTrue);
      expect(isWebLicenseKey('pro$code'), isTrue);
    });

    test('rejects reseller codes and a bare marker', () {
      expect(isWebLicenseKey(formatted), isFalse);
      expect(isWebLicenseKey('PRO'), isFalse);
      expect(isWebLicenseKey(''), isFalse);
    });
  });

  group('licenseKeyCode', () {
    test('strips the marker and formatting', () {
      expect(licenseKeyCode('PRO-$formatted'), code);
      expect(licenseKeyCode('$formatted-PRO'), code);
      expect(licenseKeyCode(formatted), code);
    });

    test('caps at 25 characters', () {
      expect(licenseKeyCode('A' * 30), 'A' * 25);
      expect(licenseKeyCode('PRO${'A' * 30}'), 'A' * 25);
    });
  });

  group('formatLicenseKey', () {
    test('groups a raw key into five-character blocks', () {
      expect(formatLicenseKey(code.toLowerCase()), formatted);
      expect(formatLicenseKey(formatted), formatted);
    });

    test('keeps the PRO marker as its own group', () {
      expect(formatLicenseKey('pro$code'), 'PRO-$formatted');
      expect(formatLicenseKey('$code-PRO'), '$formatted-PRO');
      expect(formatLicenseKey('PRO-234'), 'PRO-234');
    });

    test('drops other characters and handles empty input', () {
      expect(formatLicenseKey(' ab c!1 '), 'ABC1');
      expect(formatLicenseKey(''), '');
    });
  });

  group('ResellerCodeFormatter', () {
    TextEditingValue format(String text, [int? cursor]) =>
        ResellerCodeFormatter().formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor ?? text.length),
          ),
        );

    test(
      'formats a pasted web license key and keeps the cursor at the end',
      () {
        final value = format('pro$code');
        expect(value.text, 'PRO-$formatted');
        expect(value.selection.baseOffset, value.text.length);
      },
    );

    test('keeps the cursor after the same real character', () {
      final value = format('234678', 6);
      expect(value.text, '23467-8');
      expect(value.selection.baseOffset, 7);

      final mid = format('23467-89BCD', 7);
      expect(mid.text, '23467-89BCD');
      expect(mid.selection.baseOffset, 7);
    });

    test('truncates typing past 25 characters', () {
      final value = format('${formatted}X');
      expect(value.text, formatted);
      expect(value.selection.baseOffset, formatted.length);
    });

    test('lets the PRO suffix be typed one character at a time', () {
      var value = format('${formatted}P');
      expect(value.text, '$formatted-P');
      expect(value.selection.baseOffset, value.text.length);

      value = format('${value.text}R');
      expect(value.text, '$formatted-PR');

      value = format('${value.text}O');
      expect(value.text, '$formatted-PRO');
      expect(value.selection.baseOffset, value.text.length);
    });
  });

  group('isCompleteLicenseKey', () {
    test('accepts a full code with or without the marker', () {
      expect(isCompleteLicenseKey(formatted), isTrue);
      expect(isCompleteLicenseKey('PRO-$formatted'), isTrue);
      expect(isCompleteLicenseKey('$formatted-PRO'), isTrue);
    });

    test('rejects short codes and partial suffixes', () {
      expect(isCompleteLicenseKey('23467-89BCD'), isFalse);
      expect(isCompleteLicenseKey('$formatted-P'), isFalse);
      expect(isCompleteLicenseKey('$formatted-PR'), isFalse);
      expect(isCompleteLicenseKey(''), isFalse);
    });
  });
}
