import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/date_formatters.dart';

void main() {
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
  });
}
