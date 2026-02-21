import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_image_paths.dart';

void main() {
  group('AppImagePaths.safeFlagPath', () {
    test('returns correct path for valid 2-letter country codes', () {
      expect(AppImagePaths.safeFlagPath('us'), 'assets/images/flags/us.png');
      expect(AppImagePaths.safeFlagPath('gb'), 'assets/images/flags/gb.png');
      expect(AppImagePaths.safeFlagPath('de'), 'assets/images/flags/de.png');
    });

    test('handles uppercase country codes correctly', () {
      expect(AppImagePaths.safeFlagPath('US'), 'assets/images/flags/us.png');
      expect(AppImagePaths.safeFlagPath('GB'), 'assets/images/flags/gb.png');
    });

    test('handles country codes with whitespace', () {
      expect(AppImagePaths.safeFlagPath(' us '), 'assets/images/flags/us.png');
      expect(
          AppImagePaths.safeFlagPath('  gb  '), 'assets/images/flags/gb.png');
    });

    test('returns null for invalid country codes', () {
      // Non-existent country codes
      expect(AppImagePaths.safeFlagPath('xx'), null);
      expect(AppImagePaths.safeFlagPath('zz'), null);

      // Invalid formats
      expect(AppImagePaths.safeFlagPath('usa'), null); // 3 letters
      expect(AppImagePaths.safeFlagPath('u'), null); // 1 letter
      expect(AppImagePaths.safeFlagPath('123'), null); // numbers
      expect(AppImagePaths.safeFlagPath('u1'), null); // mixed
      expect(AppImagePaths.safeFlagPath('u-s'), null); // special chars

      // Empty or null
      expect(AppImagePaths.safeFlagPath(''), null);
      expect(AppImagePaths.safeFlagPath(null), null);
      expect(AppImagePaths.safeFlagPath('   '), null); // only whitespace
    });

    test('validates all available flag assets exist in the set', () {
      // Test a representative sample of flags from the assets
      final sampleCodes = [
        'ad',
        'ae',
        'af',
        'ag',
        'al',
        'am',
        'ao',
        'ar',
        'at',
        'au',
        'ca',
        'cn',
        'de',
        'es',
        'fr',
        'gb',
        'hk',
        'in',
        'it',
        'jp',
        'kr',
        'mo',
        'mx',
        'nl',
        'pt',
        'ru',
        'sg',
        'th',
        'us',
        'za',
      ];

      for (final code in sampleCodes) {
        expect(
          AppImagePaths.safeFlagPath(code),
          isNotNull,
          reason: 'Country code "$code" should have a flag asset',
        );
      }
    });
  });
}
