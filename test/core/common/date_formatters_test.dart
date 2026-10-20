import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lantern/core/common/date_formatters.dart';
import 'package:lantern/core/localization/i18n.dart';

void main() {
  setUpAll(initializeDateFormatting);
  tearDown(() => Localization.defaultLocale = 'en_US');

  group('AppDateFormats.dayMonthYearOrdinal', () {
    test('formats as ordinal day, full month name, two-digit year', () {
      expect(
        AppDateFormats.dayMonthYearOrdinal(DateTime(2026, 10, 12)),
        '12th October 26',
      );
    });

    test('uses the right ordinal suffix for every day of the month', () {
      final expected = {
        1: '1st',
        2: '2nd',
        3: '3rd',
        4: '4th',
        11: '11th',
        12: '12th',
        13: '13th',
        21: '21st',
        22: '22nd',
        23: '23rd',
        31: '31st',
      };
      for (final entry in expected.entries) {
        expect(
          AppDateFormats.dayMonthYearOrdinal(DateTime(2026, 1, entry.key)),
          '${entry.value} January 26',
        );
      }
    });

    test('zero-pads a single-digit year', () {
      expect(
        AppDateFormats.dayMonthYearOrdinal(DateTime(2005, 3, 1)),
        '1st March 05',
      );
    });

    test('uses the app language month name without an English suffix', () {
      Localization.defaultLocale = 'es_CU';
      expect(
        AppDateFormats.dayMonthYearOrdinal(DateTime(2026, 10, 12)),
        '12 octubre 26',
      );
    });

    test('falls back to English for a language intl has no symbols for', () {
      Localization.defaultLocale = 'tk';
      expect(
        AppDateFormats.dayMonthYearOrdinal(DateTime(2026, 10, 12)),
        '12th October 26',
      );
    });
  });
}
